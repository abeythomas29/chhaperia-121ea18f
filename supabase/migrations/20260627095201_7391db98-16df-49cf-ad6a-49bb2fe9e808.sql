
DROP FUNCTION IF EXISTS public.list_slitting_issued_materials();

CREATE FUNCTION public.list_slitting_issued_materials()
RETURNS TABLE(
  stock_issue_id uuid,
  issue_type text,
  product_code_id uuid,
  raw_material_id uuid,
  item_name text,
  issued_quantity numeric,
  consumed_quantity numeric,
  remaining_quantity numeric,
  unit text,
  thickness_mm numeric,
  gsm numeric,
  notes text,
  date date
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
  SELECT
    si.id AS stock_issue_id,
    COALESCE(si.issue_type, 'raw_material') AS issue_type,
    si.product_code_id,
    si.raw_material_id,
    COALESCE(pc.code, rm.name, '') AS item_name,
    si.quantity AS issued_quantity,
    COALESCE(c.consumed, 0)::numeric AS consumed_quantity,
    (si.quantity - COALESCE(c.consumed, 0))::numeric AS remaining_quantity,
    si.unit,
    si.thickness_mm,
    si.gsm,
    si.notes,
    si.date
  FROM public.stock_issues si
  LEFT JOIN public.product_codes pc ON pc.id = si.product_code_id
  LEFT JOIN public.raw_materials rm ON rm.id = si.raw_material_id
  LEFT JOIN LATERAL (
    SELECT SUM(COALESCE(se.source_quantity, 0)) AS consumed
    FROM public.slitting_entries se
    WHERE se.stock_issue_id = si.id
  ) c ON TRUE
  WHERE si.recipient_user_id = auth.uid()
    AND COALESCE(si.issue_type, 'raw_material') IN ('raw_material', 'finished_stock')
    AND (si.quantity - COALESCE(c.consumed, 0)) > 0
  ORDER BY si.date DESC, si.created_at DESC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.list_slitting_issued_materials() TO authenticated;

NOTIFY pgrst, 'reload schema';
