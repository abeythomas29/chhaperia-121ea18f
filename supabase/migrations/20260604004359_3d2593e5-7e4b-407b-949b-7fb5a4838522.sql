
-- 1. Re-assert handle_new_user trigger
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  requested_dept public.signup_department;
BEGIN
  requested_dept := CASE
    WHEN NEW.raw_user_meta_data->>'requested_department' = 'inventory_manager' THEN 'inventory_manager'::public.signup_department
    WHEN NEW.raw_user_meta_data->>'requested_department' = 'slitting_manager' THEN 'slitting_manager'::public.signup_department
    ELSE 'worker'::public.signup_department
  END;

  INSERT INTO public.profiles (user_id, name, employee_id, username, requested_department)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(BTRIM(NEW.raw_user_meta_data->>'name'), ''), 'New User'),
    COALESCE(NULLIF(BTRIM(NEW.raw_user_meta_data->>'employee_id'), ''), 'TBD'),
    COALESCE(NEW.email, ''),
    requested_dept
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Backfill missing profiles
INSERT INTO public.profiles (user_id, name, employee_id, username, requested_department)
SELECT u.id,
       COALESCE(NULLIF(BTRIM(u.raw_user_meta_data->>'name'),''), split_part(u.email,'@',1), 'New User'),
       COALESCE(NULLIF(BTRIM(u.raw_user_meta_data->>'employee_id'),''), 'TBD'),
       COALESCE(u.email, ''),
       CASE
         WHEN u.raw_user_meta_data->>'requested_department' = 'inventory_manager' THEN 'inventory_manager'::public.signup_department
         WHEN u.raw_user_meta_data->>'requested_department' = 'slitting_manager' THEN 'slitting_manager'::public.signup_department
         ELSE 'worker'::public.signup_department
       END
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = u.id);

-- 3. Promote admin@chhaperia.com to super_admin
INSERT INTO public.user_roles (user_id, role)
SELECT u.id, 'super_admin'
FROM auth.users u
WHERE u.email = 'admin@chhaperia.com'
  AND NOT EXISTS (
    SELECT 1 FROM public.user_roles r
    WHERE r.user_id = u.id AND r.role = 'super_admin'
  );

-- 4. Recreate admin_list_users()
CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS TABLE(id uuid, user_id uuid, name text, employee_id text, username text, status text, requested_department text, roles text[])
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO 'public', 'auth'
AS $function$
BEGIN
  IF NOT public.is_admin(auth.uid()) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    COALESCE(p.id, u.id) AS id,
    u.id AS user_id,
    COALESCE(p.name, split_part(u.email, '@', 1), 'Unknown') AS name,
    COALESCE(p.employee_id, 'TBD') AS employee_id,
    COALESCE(p.username, u.email, '') AS username,
    COALESCE(p.status, 'active') AS status,
    COALESCE(p.requested_department::text, 'worker') AS requested_department,
    COALESCE(r.roles, ARRAY[]::text[]) AS roles
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.user_id = u.id
  LEFT JOIN (
    SELECT ur.user_id, array_agg(ur.role::text) AS roles
    FROM public.user_roles ur
    GROUP BY ur.user_id
  ) r ON r.user_id = u.id
  ORDER BY COALESCE(p.name, u.email);
END;
$function$;

-- 5. Re-assert RLS for admin/super_admin reads on profiles + user_roles
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
CREATE POLICY "Admins can view all profiles"
  ON public.profiles FOR SELECT
  USING (public.is_admin(auth.uid()) OR public.has_role(auth.uid(), 'super_admin'));

DROP POLICY IF EXISTS "Admins can view all roles" ON public.user_roles;
CREATE POLICY "Admins can view all roles"
  ON public.user_roles FOR SELECT
  USING (public.is_admin(auth.uid()) OR public.has_role(auth.uid(), 'super_admin'));
