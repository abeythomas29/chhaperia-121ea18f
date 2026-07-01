-- ============================================================
-- Unit-consistent stock consumption: SQM/KG canonical, meters only for reference
-- ============================================================

-- A. Ensure GSM + direct-source columns exist (idempotent, additive only)

-- stock_issues.gsm already exists (verified). No-op safety:
ALTER TABLE public.stock_issues ADD COLUMN IF NOT EXISTS gsm numeric;

-- slitting_entries: direct-source reference for entries without stock_issue_id
ALTER TABLE public.slitting_entries
  ADD COLUMN IF NOT EXISTS source_product_code_id uuid,
  ADD COLUMN IF NOT EXISTS source_raw_material_id uuid,
  ADD COLUMN IF NOT EXISTS source_unit text,
  ADD COLUMN IF NOT EXISTS source_thickness_mm numeric,
  ADD COLUMN IF NOT EXISTS source_gsm numeric;
-- source_quantity already exists

-- production_entries: direct-source reference
ALTER TABLE public.production_entries
  ADD COLUMN IF NOT EXISTS source_product_code_id uuid,
  ADD COLUMN IF NOT EXISTS source_raw_material_id uuid,
  ADD COLUMN IF NOT EXISTS source_quantity numeric,
  ADD COLUMN IF NOT EXISTS source_unit text,
  ADD COLUMN IF NOT EXISTS source_thickness_mm numeric,
  ADD COLUMN IF NOT EXISTS source_gsm numeric;

-- ============================================================
-- B. list_manager_issued_materials: return GSM, compute sqm/kg pending consistently
--    (keeps existing signature; adds sqm/kg helper columns)
-- ============================================================
DROP FUNCTION IF EXISTS public.list_manager_issued_materials(boolean);

CREATE OR REPLACE FUNCTION public.list_manager_issued_materials(include_closed boolean DEFAULT false)
RETURNS TABLE(
  stock_issue_id uuid,
  issue_type text,
  product_code_id uuid,
  raw_material_id uuid,
  display_name text,
  product_code text,
  raw_material_name text,
  lot_no text,
  thickness_mm numeric,
  gsm numeric,
  issued_quantity numeric,
  consumed_quantity numeric,
  returned_quantity numeric,
  wastage_quantity numeric,
  pending_quantity numeric,
  pending_sqm numeric,
  pending_kg numeric,
  unit text,
  notes text,
  issue_date date
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      si.id,
      COALESCE(si.issue_type, 'raw_material') AS issue_type,
      si.product_code_id,
      si.raw_material_id,
      pc.code AS pc_code,
      rm.name AS rm_name,
      si.product_code AS si_product_code_text,
      si.lot_number,
      si.thickness_mm,
      COALESCE(si.gsm, pc.gsm) AS eff_gsm,
      COALESCE(si.issue_quantity, si.quantity, 0) AS issued_qty,
      lower(COALESCE(NULLIF(si.issue_unit, ''), si.unit, 'kg')) AS issue_unit_norm,
      COALESCE(NULLIF(si.issue_unit, ''), si.unit, 'kg') AS issue_unit_display,
      si.notes,
      si.date,
      si.created_at
    FROM public.stock_issues si
    LEFT JOIN public.product_codes pc ON pc.id = si.product_code_id
    LEFT JOIN public.raw_materials rm ON rm.id = si.raw_material_id
    WHERE si.recipient_user_id = auth.uid()
  ),
  consumed_slit AS (
    SELECT
      b.id AS stock_issue_id,
      COALESCE(SUM(
        CASE
          WHEN b.issue_unit_norm IN ('kg','kgs','kilogram','kilograms')
            THEN ((COALESCE(se.cut_width_mm,0)/1000.0) * COALESCE(se.cut_quantity_produced,0) * COALESCE(se.gsm, b.eff_gsm, 0)) / 1000.0
          WHEN b.issue_unit_norm IN ('sqm','sqmtr','sq.m','square meter','square meters','m2')
            THEN (COALESCE(se.cut_width_mm,0)/1000.0) * COALESCE(se.cut_quantity_produced,0)
          ELSE COALESCE(se.source_quantity, 0)
        END
      ), 0)::numeric AS consumed
    FROM base b
    LEFT JOIN public.slitting_entries se ON se.stock_issue_id = b.id
    GROUP BY b.id
  ),
  consumed_prod AS (
    SELECT
      b.id AS stock_issue_id,
      COALESCE(SUM(COALESCE(rmu.quantity_used, 0)), 0)::numeric AS consumed
    FROM base b
    LEFT JOIN public.raw_material_usage rmu ON rmu.stock_issue_id = b.id
    GROUP BY b.id
  ),
  returns_agg AS (
    SELECT
      b.id AS stock_issue_id,
      COALESCE(SUM(CASE WHEN COALESCE(sr.return_type,'reusable') = 'reusable'
                        THEN COALESCE(sr.returned_quantity, 0) ELSE 0 END), 0)::numeric AS returned,
      COALESCE(SUM(CASE WHEN sr.return_type = 'wastage'
                        THEN COALESCE(sr.returned_quantity, 0) + COALESCE(sr.wastage_quantity, 0)
                        ELSE COALESCE(sr.wastage_quantity, 0) END), 0)::numeric AS wastage
    FROM base b
    LEFT JOIN public.slitting_entries se ON se.stock_issue_id = b.id
    LEFT JOIN public.slitting_returns sr ON sr.slitting_entry_id = se.id
    GROUP BY b.id
  )
  SELECT
    b.id AS stock_issue_id,
    b.issue_type,
    b.product_code_id,
    b.raw_material_id,
    COALESCE(
      NULLIF(BTRIM(b.pc_code), ''),
      NULLIF(BTRIM(b.rm_name), ''),
      NULLIF(BTRIM(b.si_product_code_text), ''),
      CASE WHEN b.issue_type = 'finished_stock' THEN 'Finished Stock' ELSE 'Raw Material' END
    ) AS display_name,
    COALESCE(NULLIF(BTRIM(b.pc_code), ''), NULLIF(BTRIM(b.si_product_code_text), '')) AS product_code,
    b.rm_name AS raw_material_name,
    b.lot_number AS lot_no,
    b.thickness_mm,
    b.eff_gsm AS gsm,
    b.issued_qty AS issued_quantity,
    (COALESCE(cs.consumed,0) + COALESCE(cp.consumed,0))::numeric AS consumed_quantity,
    COALESCE(ra.returned, 0)::numeric AS returned_quantity,
    COALESCE(ra.wastage, 0)::numeric AS wastage_quantity,
    (b.issued_qty
      - COALESCE(cs.consumed,0)
      - COALESCE(cp.consumed,0)
      - COALESCE(ra.returned,0)
      - COALESCE(ra.wastage,0)
    )::numeric AS pending_quantity,
    -- sqm/kg derived from pending using eff_gsm
    CASE
      WHEN b.issue_unit_norm IN ('sqm','sqmtr','sq.m','square meter','square meters','m2')
        THEN (b.issued_qty - COALESCE(cs.consumed,0) - COALESCE(cp.consumed,0) - COALESCE(ra.returned,0) - COALESCE(ra.wastage,0))
      WHEN b.issue_unit_norm IN ('kg','kgs','kilogram','kilograms') AND COALESCE(b.eff_gsm,0) > 0
        THEN ((b.issued_qty - COALESCE(cs.consumed,0) - COALESCE(cp.consumed,0) - COALESCE(ra.returned,0) - COALESCE(ra.wastage,0)) * 1000.0) / b.eff_gsm
      ELSE NULL
    END::numeric AS pending_sqm,
    CASE
      WHEN b.issue_unit_norm IN ('kg','kgs','kilogram','kilograms')
        THEN (b.issued_qty - COALESCE(cs.consumed,0) - COALESCE(cp.consumed,0) - COALESCE(ra.returned,0) - COALESCE(ra.wastage,0))
      WHEN b.issue_unit_norm IN ('sqm','sqmtr','sq.m','square meter','square meters','m2') AND COALESCE(b.eff_gsm,0) > 0
        THEN ((b.issued_qty - COALESCE(cs.consumed,0) - COALESCE(cp.consumed,0) - COALESCE(ra.returned,0) - COALESCE(ra.wastage,0)) * b.eff_gsm) / 1000.0
      ELSE NULL
    END::numeric AS pending_kg,
    b.issue_unit_display AS unit,
    b.notes,
    b.date AS issue_date
  FROM base b
  LEFT JOIN consumed_slit cs ON cs.stock_issue_id = b.id
  LEFT JOIN consumed_prod cp ON cp.stock_issue_id = b.id
  LEFT JOIN returns_agg ra ON ra.stock_issue_id = b.id
  WHERE include_closed
     OR (b.issued_qty
          - COALESCE(cs.consumed,0)
          - COALESCE(cp.consumed,0)
          - COALESCE(ra.returned,0)
          - COALESCE(ra.wastage,0)
        ) > 0
  ORDER BY b.date DESC, b.created_at DESC;
END;
$function$;

-- Slitting delegator continues to work; recreate to pick up new columns of underlying data
CREATE OR REPLACE FUNCTION public.list_slitting_issued_materials()
RETURNS TABLE(
  stock_issue_id uuid, issue_type text, product_code_id uuid, raw_material_id uuid,
  display_name text, product_code text, raw_material_name text, lot_no text,
  thickness_mm numeric, gsm numeric,
  issued_quantity numeric, consumed_quantity numeric, remaining_quantity numeric,
  unit text, notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT m.stock_issue_id, m.issue_type, m.product_code_id, m.raw_material_id,
         m.display_name, m.product_code, m.raw_material_name, m.lot_no,
         m.thickness_mm, m.gsm,
         m.issued_quantity, m.consumed_quantity, m.pending_quantity AS remaining_quantity,
         m.unit, m.notes
  FROM public.list_manager_issued_materials(false) m;
END;
$function$;

-- ============================================================
-- C. list_stock_issues: return GSM column (add to signature)
-- ============================================================
DROP FUNCTION IF EXISTS public.list_stock_issues();

CREATE OR REPLACE FUNCTION public.list_stock_issues()
RETURNS TABLE(
  id uuid, date date, issue_type text,
  product_code_id uuid, product_code text,
  raw_material_id uuid, raw_material_name text,
  quantity numeric, unit text, thickness_mm numeric, gsm numeric,
  client_id uuid, client_name text,
  recipient_type text, recipient_user_id uuid, recipient_name text,
  issued_by uuid, issued_by_name text,
  notes text, created_at timestamp with time zone
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
  v_privileged boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_privileged := public.is_admin(auth.uid())
    OR public.has_role(auth.uid(), 'inventory_manager');

  RETURN QUERY
  SELECT
    si.id, si.date, COALESCE(si.issue_type, 'finished_stock'),
    si.product_code_id, pc.code,
    si.raw_material_id, rm.name,
    si.quantity, si.unit, si.thickness_mm,
    COALESCE(si.gsm, pc.gsm) AS gsm,
    si.client_id, cc.name,
    si.recipient_type, si.recipient_user_id, pr.name,
    si.issued_by, pb.name,
    si.notes, si.created_at
  FROM public.stock_issues si
  LEFT JOIN public.product_codes pc ON pc.id = si.product_code_id
  LEFT JOIN public.raw_materials rm ON rm.id = si.raw_material_id
  LEFT JOIN public.company_clients cc ON cc.id = si.client_id
  LEFT JOIN public.profiles pr ON pr.user_id = si.recipient_user_id
  LEFT JOIN public.profiles pb ON pb.user_id = si.issued_by
  WHERE v_privileged OR si.recipient_user_id = auth.uid()
  ORDER BY si.date DESC, si.created_at DESC;
END;
$function$;

-- ============================================================
-- D. list_36_head_source_slitting_entries: sqm/kg pending + validation helpers
-- ============================================================
DROP FUNCTION IF EXISTS public.list_36_head_source_slitting_entries();

CREATE OR REPLACE FUNCTION public.list_36_head_source_slitting_entries()
RETURNS TABLE(
  slitting_entry_id uuid,
  stock_issue_id uuid,
  issue_type text,
  product_code_id uuid,
  display_name text,
  client_id uuid,
  client_name text,
  lot_no text,
  thickness_mm numeric,
  gsm numeric,
  cut_width_mm numeric,
  unit text,
  primary_issued_quantity numeric,
  primary_consumed_in_slitting numeric,
  primary_pending_quantity numeric,
  secondary_slitting_produced_quantity numeric,
  secondary_slitting_produced_sqm numeric,
  secondary_slitting_produced_kg numeric,
  secondary_consumed_in_36_head numeric,
  secondary_consumed_36_head_sqm numeric,
  secondary_consumed_36_head_kg numeric,
  secondary_pending_quantity numeric,
  secondary_pending_unit text,
  secondary_pending_sqm numeric,
  secondary_pending_kg numeric,
  date date,
  notes text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  WITH base AS (
    SELECT
      se.id AS slitting_entry_id,
      se.stock_issue_id,
      COALESCE(si.issue_type, 'raw_material') AS issue_type,
      COALESCE(si.product_code_id, se.product_code_id) AS product_code_id,
      COALESCE(
        NULLIF(BTRIM(pc.code), ''),
        NULLIF(BTRIM(rm.name), ''),
        NULLIF(BTRIM(si.product_code), ''),
        'Material'
      ) AS display_name,
      si.client_id,
      cc.name AS client_name,
      si.lot_number AS lot_no,
      COALESCE(se.thickness_mm, si.thickness_mm) AS thickness_mm,
      COALESCE(se.gsm, si.gsm, pc.gsm) AS eff_gsm,
      se.cut_width_mm,
      lower(COALESCE(NULLIF(si.issue_unit,''), si.unit, se.unit, 'kg')) AS issue_unit_norm,
      COALESCE(NULLIF(si.issue_unit,''), si.unit, se.unit, 'kg') AS issue_unit_display,
      COALESCE(si.issue_quantity, si.quantity, 0) AS primary_issued,
      COALESCE(se.cut_quantity_produced, 0) AS produced_qty,
      lower(COALESCE(NULLIF(se.unit,''), 'sqmtr')) AS se_unit_norm,
      se.date,
      se.notes
    FROM public.slitting_entries se
    LEFT JOIN public.stock_issues si ON si.id = se.stock_issue_id
    LEFT JOIN public.product_codes pc ON pc.id = COALESCE(si.product_code_id, se.product_code_id)
    LEFT JOIN public.raw_materials rm ON rm.id = si.raw_material_id
    LEFT JOIN public.company_clients cc ON cc.id = si.client_id
    WHERE (
      se.slitting_manager_id = auth.uid()
      OR si.recipient_user_id = auth.uid()
      OR si.issued_to_user_id = auth.uid()
    )
  ),
  primary_consumed AS (
    SELECT
      b.stock_issue_id,
      COALESCE(SUM(
        CASE
          WHEN b.issue_unit_norm IN ('kg','kgs','kilogram','kilograms')
            THEN ((COALESCE(se2.cut_width_mm,0)/1000.0) * COALESCE(se2.cut_quantity_produced,0) * COALESCE(se2.gsm, b.eff_gsm, 0)) / 1000.0
          WHEN b.issue_unit_norm IN ('sqm','sqmtr','sq.m','square meter','square meters','m2')
            THEN (COALESCE(se2.cut_width_mm,0)/1000.0) * COALESCE(se2.cut_quantity_produced,0)
          ELSE COALESCE(se2.source_quantity, 0)
        END
      ), 0)::numeric AS consumed
    FROM (SELECT DISTINCT stock_issue_id, issue_unit_norm, eff_gsm FROM base WHERE stock_issue_id IS NOT NULL) b
    LEFT JOIN public.slitting_entries se2 ON se2.stock_issue_id = b.stock_issue_id
    GROUP BY b.stock_issue_id
  ),
  primary_returns AS (
    SELECT
      se2.stock_issue_id,
      COALESCE(SUM(COALESCE(sr.returned_quantity,0) + COALESCE(sr.wastage_quantity,0)), 0)::numeric AS returned_total
    FROM public.slitting_entries se2
    LEFT JOIN public.slitting_returns sr ON sr.slitting_entry_id = se2.id
    WHERE se2.stock_issue_id IS NOT NULL
    GROUP BY se2.stock_issue_id
  ),
  -- Secondary consumption: 36 head takes from slitting output.
  -- Compute sqm and kg from the 36 head entry's own tape geometry.
  secondary_consumed AS (
    SELECT
      h.slitting_entry_id,
      COALESCE(SUM(COALESCE(h.rolls_taken, h.rolls_produced, 0)), 0)::numeric AS consumed_rolls_or_qty,
      COALESCE(SUM(
        (COALESCE(h.roll_width_mm,0)/1000.0)
        * COALESCE(h.length_per_tape_mtr,0)
        * COALESCE(h.rolls_produced, h.rolls_taken, 0)
      ), 0)::numeric AS consumed_sqm
    FROM public.head36_entries h
    WHERE h.slitting_entry_id IS NOT NULL
    GROUP BY h.slitting_entry_id
  )
  SELECT
    b.slitting_entry_id,
    b.stock_issue_id,
    b.issue_type,
    b.product_code_id,
    b.display_name,
    b.client_id,
    b.client_name,
    b.lot_no,
    b.thickness_mm,
    b.eff_gsm AS gsm,
    b.cut_width_mm,
    b.issue_unit_display AS unit,
    b.primary_issued AS primary_issued_quantity,
    COALESCE(pc.consumed, 0) AS primary_consumed_in_slitting,
    (b.primary_issued - COALESCE(pc.consumed,0) - COALESCE(pr.returned_total,0))::numeric AS primary_pending_quantity,
    b.produced_qty AS secondary_slitting_produced_quantity,
    -- produced sqm/kg derived from slitting entry (unit-aware)
    (CASE
      WHEN b.se_unit_norm IN ('sqm','sqmtr','sq.m','square meter','square meters','m2')
        THEN b.produced_qty
      WHEN b.se_unit_norm IN ('kg','kgs','kilogram','kilograms') AND COALESCE(b.eff_gsm,0) > 0
        THEN (b.produced_qty * 1000.0) / b.eff_gsm
      WHEN b.se_unit_norm IN ('meters','meter','mtr','m') AND COALESCE(b.cut_width_mm,0) > 0
        THEN (b.cut_width_mm/1000.0) * b.produced_qty
      ELSE NULL
    END)::numeric AS secondary_slitting_produced_sqm,
    (CASE
      WHEN b.se_unit_norm IN ('kg','kgs','kilogram','kilograms')
        THEN b.produced_qty
      WHEN b.se_unit_norm IN ('sqm','sqmtr','sq.m','square meter','square meters','m2') AND COALESCE(b.eff_gsm,0) > 0
        THEN (b.produced_qty * b.eff_gsm) / 1000.0
      WHEN b.se_unit_norm IN ('meters','meter','mtr','m') AND COALESCE(b.cut_width_mm,0) > 0 AND COALESCE(b.eff_gsm,0) > 0
        THEN ((b.cut_width_mm/1000.0) * b.produced_qty * b.eff_gsm) / 1000.0
      ELSE NULL
    END)::numeric AS secondary_slitting_produced_kg,
    COALESCE(sc.consumed_rolls_or_qty, 0)::numeric AS secondary_consumed_in_36_head,
    COALESCE(sc.consumed_sqm, 0)::numeric AS secondary_consumed_36_head_sqm,
    (COALESCE(sc.consumed_sqm,0) * COALESCE(b.eff_gsm,0) / 1000.0)::numeric AS secondary_consumed_36_head_kg,
    -- secondary pending in slitting-entry native units (backward-compatible field)
    (b.produced_qty - COALESCE(sc.consumed_rolls_or_qty,0))::numeric AS secondary_pending_quantity,
    (CASE
      WHEN b.se_unit_norm IN ('kg','kgs','kilogram','kilograms') THEN 'kg'
      ELSE 'sqm'
    END)::text AS secondary_pending_unit,
    -- pending in sqm = produced_sqm - consumed_sqm
    (
      (CASE
        WHEN b.se_unit_norm IN ('sqm','sqmtr','sq.m','square meter','square meters','m2') THEN b.produced_qty
        WHEN b.se_unit_norm IN ('kg','kgs','kilogram','kilograms') AND COALESCE(b.eff_gsm,0) > 0 THEN (b.produced_qty * 1000.0) / b.eff_gsm
        WHEN b.se_unit_norm IN ('meters','meter','mtr','m') AND COALESCE(b.cut_width_mm,0) > 0 THEN (b.cut_width_mm/1000.0) * b.produced_qty
        ELSE 0
      END)
      - COALESCE(sc.consumed_sqm, 0)
    )::numeric AS secondary_pending_sqm,
    -- pending in kg from pending sqm * gsm/1000
    (
      (
        (CASE
          WHEN b.se_unit_norm IN ('sqm','sqmtr','sq.m','square meter','square meters','m2') THEN b.produced_qty
          WHEN b.se_unit_norm IN ('kg','kgs','kilogram','kilograms') AND COALESCE(b.eff_gsm,0) > 0 THEN (b.produced_qty * 1000.0) / b.eff_gsm
          WHEN b.se_unit_norm IN ('meters','meter','mtr','m') AND COALESCE(b.cut_width_mm,0) > 0 THEN (b.cut_width_mm/1000.0) * b.produced_qty
          ELSE 0
        END)
        - COALESCE(sc.consumed_sqm, 0)
      ) * COALESCE(b.eff_gsm, 0) / 1000.0
    )::numeric AS secondary_pending_kg,
    b.date,
    b.notes
  FROM base b
  LEFT JOIN primary_consumed pc ON pc.stock_issue_id = b.stock_issue_id
  LEFT JOIN primary_returns pr ON pr.stock_issue_id = b.stock_issue_id
  LEFT JOIN secondary_consumed sc ON sc.slitting_entry_id = b.slitting_entry_id
  -- Show as available if pending sqm > 0 (unit-consistent), fallback to native qty
  WHERE (
    (CASE
      WHEN b.se_unit_norm IN ('sqm','sqmtr','sq.m','square meter','square meters','m2') THEN b.produced_qty
      WHEN b.se_unit_norm IN ('kg','kgs','kilogram','kilograms') AND COALESCE(b.eff_gsm,0) > 0 THEN (b.produced_qty * 1000.0) / b.eff_gsm
      WHEN b.se_unit_norm IN ('meters','meter','mtr','m') AND COALESCE(b.cut_width_mm,0) > 0 THEN (b.cut_width_mm/1000.0) * b.produced_qty
      ELSE b.produced_qty
    END) - COALESCE(sc.consumed_sqm, 0)
  ) > 0
  ORDER BY b.date DESC;
END;
$function$;

NOTIFY pgrst, 'reload schema';
