## Context

Your app's `.env` and `src/integrations/supabase/client.ts` still point at the **original** backend (`eezbgxbbgaqifgcxxbun`), and that backend already has all 17 users + profiles + roles + `admin_list_users()`. So User Management works fine on the original.

The "users missing" problem is on the **new** Supabase project you migrated to. The schema and `public` data made it across, but `auth.users` did not — that's why:
- Admin → User Management is empty (no rows in `auth.users` to join).
- New signups can't actually use the app (no trigger ran, or profiles exist but the linked `auth.users` row was never reachable).

Splitting auth between two backends is not viable — RLS uses `auth.uid()` from the JWT, and the JWT issuer must be the same project that owns the data. So we re-import auth users into the new backend instead.

## Plan

### 1. Confirm which project is the "new" backend
I need the new Supabase project ref (the `xxxx` in `https://xxxx.supabase.co`) and confirmation that you have its non-pooled `postgres` superuser connection string from Project Settings → Database → Connection string → URI (use the one that starts with `postgresql://postgres:...@db.xxxx.supabase.co:5432/postgres`, NOT the pooler `6543` one).

### 2. Re-run the auth import bundle against the new project
Using the `02_auth_users.sql` file from the migration bundle I generated earlier, run:

```bash
psql "postgresql://postgres:<password>@db.<NEW_REF>.supabase.co:5432/postgres" \
  -v ON_ERROR_STOP=1 -f 02_auth_users.sql
```

This inserts into `auth.users` and `auth.identities` with the original UUIDs and password hashes, so:
- Existing profiles / user_roles rows (already in the new DB) reconnect by `user_id`.
- Users keep their existing passwords.

### 3. Re-assert the signup trigger on the new project
The `handle_new_user()` function and the `on_auth_user_created` trigger on `auth.users` may not have been re-created in the new project. I'll generate a small migration on the new project that:
- Re-creates `public.handle_new_user()` (idempotent `CREATE OR REPLACE`).
- Drops + re-creates `on_auth_user_created AFTER INSERT ON auth.users` so new signups always get a profile row.

### 4. Backfill any orphaned rows
A safe additive `INSERT … SELECT … WHERE NOT EXISTS` to:
- Add a `profiles` row for any `auth.users` without one.
- Leave `user_roles` empty for new users so they land in Pending (matches your existing flow).

### 5. Point the app at the new backend (only when you're ready)
Update `.env` and `src/integrations/supabase/client.ts` with the new project URL + anon key. Until you do this, the live app keeps using the original backend and nothing changes for current users.

### 6. Verify
- `SELECT count(*) FROM auth.users;` on the new project = 17.
- Log in as admin on the app pointed at the new backend → User Management shows all 17.
- Sign up a new test user → row appears in `auth.users`, `profiles` auto-created, account is Pending.

## What I need from you to proceed in build mode

1. The **new project ref** (e.g. `abcd1234efgh5678ijkl`).
2. Confirmation you still have the bundle I generated (`01_schema_public.sql`, `02_auth_users.sql`, `03_data_public.sql`). If not, I'll regenerate `02_auth_users.sql` from the original backend.
3. Whether you want me to also write the trigger + backfill SQL as a file you can run with `psql`, or apply it via the Supabase SQL editor on the new project.

## Out of scope
- No changes to the original `mica1` backend.
- No splitting auth across two projects.
- No frontend behavior changes — only the connection target changes in step 5.
