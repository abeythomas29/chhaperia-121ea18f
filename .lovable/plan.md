# Repair User Directory on Connected Backend

## Root cause (verified)

I queried the live backend. All 17 auth users already have `public.profiles` rows, and `admin_list_users()`, `handle_new_user()`, and `is_admin()` already exist. The reason **Admin → Users** shows "Not authorized" is simpler: **`admin@chhaperia.com` has no row in `public.user_roles`**, so `is_admin(auth.uid())` returns false and `admin_list_users()` raises `Not authorized`.

Other users without roles (and therefore stuck on Pending): `abey1234@gmail.com`, `awesomeabey@gmail.com`. They are not the issue — they just need approval through the UI once admin can log in.

The named migration file `supabase/migrations/20260604120000_repair_original_backend_user_directory.sql` does not exist in the repo yet. I will create it and run it via the migration tool.

## What the migration will do (non-destructive)

1. Re-assert `handle_new_user()` and the `on_auth_user_created` trigger on `auth.users` so new signups always get a profile row.
2. Backfill `public.profiles` from `auth.users` using `INSERT … WHERE NOT EXISTS` (no rows to insert today, kept for safety).
3. Insert `('super_admin', admin@chhaperia.com)` into `public.user_roles` if missing — leaves all other roles untouched.
4. Re-create `public.admin_list_users()` exactly as it is today (idempotent `CREATE OR REPLACE`).
5. Re-assert RLS policies so both `admin` and `super_admin` can read `public.profiles` and `public.user_roles` (current policies already cover this via `is_admin()` / `has_role(..., 'super_admin')`, but they will be dropped and recreated to guarantee state).

No `DROP TABLE`, no `DELETE`, no `TRUNCATE`. Existing `user_roles`, `profiles`, and all production/inventory/slitting data are untouched.

## Technical detail

```sql
-- 1. Trigger
CREATE OR REPLACE FUNCTION public.handle_new_user() ... ; -- existing body
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Backfill profiles
INSERT INTO public.profiles (user_id, name, employee_id, username, requested_department)
SELECT u.id,
       COALESCE(NULLIF(BTRIM(u.raw_user_meta_data->>'name'),''), split_part(u.email,'@',1), 'New User'),
       COALESCE(NULLIF(BTRIM(u.raw_user_meta_data->>'employee_id'),''), 'TBD'),
       COALESCE(u.email, ''),
       'worker'::public.signup_department
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = u.id);

-- 3. Promote admin
INSERT INTO public.user_roles (user_id, role)
SELECT u.id, 'super_admin'
FROM auth.users u
WHERE u.email = 'admin@chhaperia.com'
  AND NOT EXISTS (
    SELECT 1 FROM public.user_roles r
    WHERE r.user_id = u.id AND r.role = 'super_admin'
  );

-- 4. admin_list_users() — CREATE OR REPLACE with current body

-- 5. RLS re-assert on profiles + user_roles for admin/super_admin reads
```

## Verification after apply

1. Re-run `SELECT role FROM public.user_roles WHERE user_id = (SELECT id FROM auth.users WHERE email='admin@chhaperia.com');` → expect `super_admin`.
2. Log in as `admin@chhaperia.com`, open **Admin → User Management** → expect all 17 users listed, with `abey1234@gmail.com` and `awesomeabey@gmail.com` shown under **Pending Approvals**.
3. Confirm no other user's roles changed (compare against the count I captured: 17 users, 14 with at least one role).

## Out of scope

- Migrating data/auth to a different Supabase project (the earlier discussion). This plan only repairs the currently-connected backend.
- Approving the two pending users — admin can do that in the UI once they can log in.
