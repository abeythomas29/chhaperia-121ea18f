
-- 1. Ensure head36_entries has stock_issue_id link
ALTER TABLE public.head36_entries
  ADD COLUMN IF NOT EXISTS stock_issue_id uuid REFERENCES public.stock_issues(id);

CREATE INDEX IF NOT EXISTS idx_head36_entries_slitting_entry_id ON public.head36_entries(slitting_entry_id);
CREATE INDEX IF NOT EXISTS idx_head36_entries_stock_issue_id ON public.head36_entries(stock_issue_id);

-- 2. RPC: source slitting entries for 36 Head production
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
  unit text,
  primary_issued_quantity numeric,
  primary_consumed_in_slitting numeric,
  primary_pending_quantity numeric,
  secondary_slitting_produced_quantity numeric,
  secondary_consumed_in_36_head numeric,
  secondary_pending_quantity numeric,
  date date,
  notes text
)
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
      se.id AS slitting_entry_id,
      se.stock_issue_id,
      COALESCE(si.issue_type, 'raw_material') AS issue_type,
      si.product_code_id,
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
      COALESCE(se.gsm, si.gsm) AS gsm,
      lower(COALESCE(NULLIF(si.issue_unit, ''), si.unit, 'kg')) AS issue_unit_norm,
      COALESCE(NULLIF(si.issue_unit, ''), si.unit, 'kg') AS issue_unit_display,
      COALESCE(si.issue_quantity, si.quantity, 0) AS primary_issued,
      COALESCE(se.cut_quantity_produced, 0) AS produced_qty,
      se.date,
      se.notes
    FROM public.slitting_entries se
    JOIN public.stock_issues si ON si.id = se.stock_issue_id
    LEFT JOIN public.product_codes pc ON pc.id = si.product_code_id
    LEFT JOIN public.raw_materials rm ON rm.id = si.raw_material_id
    LEFT JOIN public.company_clients cc ON cc.id = si.client_id
    WHERE se.stock_issue_id IS NOT NULL
      AND (
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
            THEN ((COALESCE(se2.cut_width_mm,0)/1000.0) * COALESCE(se2.cut_quantity_produced,0) * COALESCE(se2.gsm, b.gsm, 0)) / 1000.0
          WHEN b.issue_unit_norm IN ('sqm','sq.m','square meter','square meters','m2')
            THEN (COALESCE(se2.cut_width_mm,0)/1000.0) * COALESCE(se2.cut_quantity_produced,0)
          ELSE COALESCE(se2.source_quantity, 0)
        END
      ), 0)::numeric AS consumed
    FROM (SELECT DISTINCT stock_issue_id, issue_unit_norm, gsm FROM base) b
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
  secondary_consumed AS (
    SELECT
      h.slitting_entry_id,
      COALESCE(SUM(COALESCE(h.rolls_taken, h.rolls_produced, 0)), 0)::numeric AS consumed
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
    b.gsm,
    b.issue_unit_display AS unit,
    b.primary_issued AS primary_issued_quantity,
    COALESCE(pc.consumed, 0) AS primary_consumed_in_slitting,
    (b.primary_issued - COALESCE(pc.consumed,0) - COALESCE(pr.returned_total,0))::numeric AS primary_pending_quantity,
    b.produced_qty AS secondary_slitting_produced_quantity,
    COALESCE(sc.consumed, 0) AS secondary_consumed_in_36_head,
    (b.produced_qty - COALESCE(sc.consumed,0))::numeric AS secondary_pending_quantity,
    b.date,
    b.notes
  FROM base b
  LEFT JOIN primary_consumed pc ON pc.stock_issue_id = b.stock_issue_id
  LEFT JOIN primary_returns pr ON pr.stock_issue_id = b.stock_issue_id
  LEFT JOIN secondary_consumed sc ON sc.slitting_entry_id = b.slitting_entry_id
  WHERE (b.produced_qty - COALESCE(sc.consumed,0)) > 0
  ORDER BY b.date DESC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.list_36_head_source_slitting_entries() TO authenticated;

NOTIFY pgrst, 'reload schema';
