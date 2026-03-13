-- Use Supabase's built-in password update mechanism
-- First verify the current password hash format
SELECT substring(encrypted_password from 1 for 10) as hash_prefix FROM auth.users WHERE id = '02c56bdd-187a-4da6-b536-01cda63d99ed';