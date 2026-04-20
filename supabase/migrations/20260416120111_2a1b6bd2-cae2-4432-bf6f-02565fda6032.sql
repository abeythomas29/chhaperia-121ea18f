ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'inventory_manager';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_namespace n ON n.oid = t.typnamespace
    WHERE n.nspname = 'public'
      AND t.typname = 'signup_department'
  ) THEN
    CREATE TYPE public.signup_department AS ENUM ('worker', 'inventory_manager');
  END IF;
END $$;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS requested_department public.signup_department;

UPDATE public.profiles
SET requested_department = 'worker'::public.signup_department
WHERE requested_department IS NULL;

ALTER TABLE public.profiles
ALTER COLUMN requested_department SET DEFAULT 'worker'::public.signup_department;

ALTER TABLE public.profiles
ALTER COLUMN requested_department SET NOT NULL;

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
    ELSE 'worker'::public.signup_department
  END;

  INSERT INTO public.profiles (user_id, name, employee_id, username, requested_department)
  VALUES (
    NEW.id,
    COALESCE(NULLIF(BTRIM(NEW.raw_user_meta_data->>'name'), ''), 'New User'),
    COALESCE(NULLIF(BTRIM(NEW.raw_user_meta_data->>'employee_id'), ''), 'TBD'),
    COALESCE(NEW.email, ''),
    requested_dept
  );

  RETURN NEW;
END;
$function$;