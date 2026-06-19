CREATE OR REPLACE FUNCTION public.list_production_manager_recipients()
RETURNS TABLE (
  user_id uuid,
  name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
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
  SELECT DISTINCT
    p.user_id,
    COALESCE(NULLIF(BTRIM(p.name), ''), 'Unknown') AS name
  FROM public.profiles p
  JOIN public.user_roles ur ON ur.user_id = p.user_id
  WHERE p.status = 'active'
    AND ur.role::text = 'worker'
  ORDER BY name;
END;
$$;

REVOKE ALL ON FUNCTION public.list_production_manager_recipients() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.list_production_manager_recipients() TO authenticated;

NOTIFY pgrst, 'reload schema';