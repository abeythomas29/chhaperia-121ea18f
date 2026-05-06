## Problem

The `handle_new_user` database trigger is missing in the Live environment. This trigger should fire on every new signup and automatically create a row in the `profiles` table. Without it:
- Users sign up successfully (auth record created) but get no profile
- They see "waiting for approval" because the admin panel only shows users with profiles
- Re-signing up shows "user already registered"

17 users in Live have auth accounts but no profiles.

## Plan

### Step 1: Re-create the trigger via migration

Run a migration that:
- Creates the trigger `on_auth_user_created` on `auth.users` AFTER INSERT, calling `handle_new_user()`
- The function already exists in Live, only the trigger is missing

### Step 2: Backfill missing profiles in Live

Insert profiles for the 17 orphaned auth users using their `raw_user_meta_data` (name, employee_id, requested_department). This will make them immediately visible in the admin panel for approval.

Key users that will be fixed:
- `abhishek@chhaperia.com`
- `slitting@chhaperia.com`
- And 15 other test/legacy accounts

### Step 3: Capacitor Android app

The Android app issue is separate — it's pointing to the Test/preview URL. You'll need to update `server.url` in your local Capacitor config to `https://chhaperia.micagroup.net` and run `npx cap sync` to use the Live database.

## Technical Details

- Migration: `CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();`
- Backfill: INSERT into profiles using data from `auth.users.raw_user_meta_data`
- No code changes needed — the app logic is correct, just the trigger was missing
