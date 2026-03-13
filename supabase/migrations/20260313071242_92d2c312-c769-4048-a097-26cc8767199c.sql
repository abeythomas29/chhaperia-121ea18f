-- Reset password for abey@chhaperia.com using a temporary function
CREATE OR REPLACE FUNCTION public._temp_reset_password()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update password in auth.users via crypt
  UPDATE auth.users 
  SET encrypted_password = crypt('abey1234', gen_salt('bf'))
  WHERE id = '02c56bdd-187a-4da6-b536-01cda63d99ed';
END;
$$;

SELECT public._temp_reset_password();

DROP FUNCTION public._temp_reset_password();