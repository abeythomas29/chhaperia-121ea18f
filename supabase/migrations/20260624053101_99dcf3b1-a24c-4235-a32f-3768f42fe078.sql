CREATE OR REPLACE FUNCTION public.list_stock_issues()
 RETURNS TABLE(id uuid, date date, issue_type text, product_code_id uuid, product_code text, raw_material_id uuid, raw_material_name text, quantity numeric, unit text, thickness_mm numeric, gsm numeric, client_id uuid, client_name text, issued_to_user_id uuid, recipient_name text, recipient_type text, issued_by uuid, issued_by_name text, notes text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_is_privileged boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_is_privileged := public.is_admin(auth.uid())
    OR public.has_role(auth.uid(), 'inventory_manager');

  RETURN QUERY
  SELECT
    si.id,
    si.date,
    COALESCE(si.issue_type, 'finished_stock') AS issue_type,
    si.product_code_id,
    COALESCE(pc.code, si.product_code) AS product_code,
    si.raw_material_id,
    rm.name AS raw_material_name,
    si.quantity,
    si.unit,
    si.thickness_mm,
    si.gsm,
    si.client_id,
    cc.name AS client_name,
    COALESCE(si.issued_to_user_id, si.recipient_user_id) AS issued_to_user_id,
    pr.name AS recipient_name,
    si.recipient_type,
    si.issued_by,
    pb.name AS issued_by_name,
    si.notes,
    si.created_at
  FROM public.stock_issues si
  LEFT JOIN public.product_codes pc ON pc.id = si.product_code_id
  LEFT JOIN public.raw_materials rm ON rm.id = si.raw_material_id
  LEFT JOIN public.company_clients cc ON cc.id = si.client_id
  LEFT JOIN public.profiles pr ON pr.user_id = COALESCE(si.issued_to_user_id, si.recipient_user_id)
  LEFT JOIN public.profiles pb ON pb.user_id = si.issued_by
  WHERE
    v_is_privileged
    OR si.issued_to_user_id = auth.uid()
    OR si.recipient_user_id = auth.uid()
    OR si.issued_by = auth.uid()
  ORDER BY si.date DESC, si.created_at DESC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.list_stock_issues() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_slitting_issued_materials() TO authenticated;

NOTIFY pgrst, 'reload schema';