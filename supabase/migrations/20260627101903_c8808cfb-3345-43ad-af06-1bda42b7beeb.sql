
DROP FUNCTION IF EXISTS public.list_slitting_issued_materials();

CREATE OR REPLACE FUNCTION public.list_slitting_issued_materials()
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
  remaining_quantity numeric,
  unit text,
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
      si.id,
      COALESCE(si.issue_type, 'raw_material') AS issue_type,
      si.product_code_id,
      si.raw_material_id,
      pc.code AS pc_code,
      rm.name AS rm_name,
      si.product_code AS si_product_code_text,
      si.lot_number,
      si.thickness_mm,
      si.gsm,
      COALESCE(si.issue_quantity, si.quantity) AS issued_qty,
      COALESCE(NULLIF(si.issue_unit, ''), si.unit, 'kg') AS issue_unit,
      si.notes,
      si.date,
      si.created_at
    FROM public.stock_issues si
    LEFT JOIN public.product_codes pc ON pc.id = si.product_code_id
    LEFT JOIN public.raw_materials rm ON rm.id = si.raw_material_id
    WHERE si.recipient_user_id = auth.uid()
  ),
  consumed AS (
    SELECT
      b.id AS stock_issue_id,
      COALESCE(SUM(
        CASE
          WHEN lower(b.issue_unit) IN ('kg','kgs','kilogram','kilograms')
            THEN ((COALESCE(se.cut_width_mm,0)/1000.0) * COALESCE(se.cut_quantity_produced,0) * COALESCE(se.gsm,0)) / 1000.0
          WHEN lower(b.issue_unit) IN ('sqm','sq.m','square meter','square meters','m2')
            THEN (COALESCE(se.cut_width_mm,0)/1000.0) * COALESCE(se.cut_quantity_produced,0)
          ELSE COALESCE(se.source_quantity, 0)
        END
      ), 0)::numeric AS consumed
    FROM base b
    LEFT JOIN public.slitting_entries se ON se.stock_issue_id = b.id
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
    b.gsm,
    b.issued_qty AS issued_quantity,
    COALESCE(c.consumed, 0)::numeric AS consumed_quantity,
    (b.issued_qty - COALESCE(c.consumed, 0))::numeric AS remaining_quantity,
    b.issue_unit AS unit,
    b.notes
  FROM base b
  LEFT JOIN consumed c ON c.stock_issue_id = b.id
  WHERE (b.issued_qty - COALESCE(c.consumed, 0)) > 0
  ORDER BY b.date DESC, b.created_at DESC;
END;
$function$;

NOTIFY pgrst, 'reload schema';
