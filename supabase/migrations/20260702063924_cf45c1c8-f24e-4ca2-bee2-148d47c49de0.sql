
-- 1. Ensure product_codes has a gsm column so default lookups work
ALTER TABLE public.product_codes ADD COLUMN IF NOT EXISTS gsm numeric;

-- 2. Rewrite list_manager_issued_materials: gsm = COALESCE(si.gsm, pc.gsm)
CREATE OR REPLACE FUNCTION public.list_manager_issued_materials(include_closed boolean DEFAULT false)
 RETURNS TABLE(stock_issue_id uuid, issue_type text, product_code_id uuid, raw_material_id uuid, display_name text, product_code text, raw_material_name text, lot_no text, thickness_mm numeric, gsm numeric, issued_quantity numeric, consumed_quantity numeric, returned_quantity numeric, wastage_quantity numeric, pending_quantity numeric, pending_sqm numeric, pending_kg numeric, unit text, notes text, issue_date date)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
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
      -- prefer explicit stock_issues.gsm; fall back to product default only when null
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

-- 3. Ensure list_slitting_issued_materials forwards gsm explicitly
CREATE OR REPLACE FUNCTION public.list_slitting_issued_materials()
 RETURNS TABLE(stock_issue_id uuid, issue_type text, product_code_id uuid, raw_material_id uuid, display_name text, product_code text, raw_material_name text, lot_no text, thickness_mm numeric, gsm numeric, issued_quantity numeric, consumed_quantity numeric, remaining_quantity numeric, unit text, notes text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT m.stock_issue_id, m.issue_type, m.product_code_id, m.raw_material_id,
         m.display_name, m.product_code, m.raw_material_name, m.lot_no,
         m.thickness_mm,
         m.gsm,
         m.issued_quantity, m.consumed_quantity, m.pending_quantity AS remaining_quantity,
         m.unit, m.notes
  FROM public.list_manager_issued_materials(false) m;
END;
$function$;

NOTIFY pgrst, 'reload schema';
