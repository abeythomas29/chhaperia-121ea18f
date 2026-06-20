CREATE OR REPLACE FUNCTION public.list_production_manager_recipients()
RETURNS TABLE(user_id uuid, name text)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF NOT (
    public.is_admin(auth.uid())
    OR public.has_role(auth.uid(), 'worker')
    OR public.has_role(auth.uid(), 'inventory_manager')
    OR public.has_role(auth.uid(), 'slitting_manager')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  WITH eligible_users AS (
    SELECT ur.user_id
    FROM public.user_roles ur
    WHERE ur.role::text IN ('worker', 'slitting_manager')
    UNION
    SELECT pe.worker_id AS user_id
    FROM public.production_entries pe
    WHERE pe.worker_id IS NOT NULL
    UNION
    SELECT se.slitting_manager_id AS user_id
    FROM public.slitting_entries se
    WHERE se.slitting_manager_id IS NOT NULL
  )
  SELECT DISTINCT
    p.user_id,
    COALESCE(NULLIF(BTRIM(p.name), ''), 'Unknown') AS name
  FROM public.profiles p
  JOIN eligible_users eu ON eu.user_id = p.user_id
  WHERE p.status = 'active'
  ORDER BY name;
END;
$function$;

REVOKE ALL ON FUNCTION public.list_production_manager_recipients() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_production_manager_recipients() TO authenticated;

NOTIFY pgrst, 'reload schema';