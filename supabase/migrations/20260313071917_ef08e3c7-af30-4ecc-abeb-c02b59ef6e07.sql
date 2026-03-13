-- Create a trigger function that auto-creates profile and role on new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  -- Insert profile using metadata passed during signUp
  INSERT INTO public.profiles (user_id, name, employee_id, username)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'New User'),
    COALESCE(NEW.raw_user_meta_data->>'employee_id', 'TBD'),
    COALESCE(NEW.email, '')
  );

  -- Assign default worker role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'worker');

  RETURN NEW;
END;
$$;

-- Create trigger on auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();