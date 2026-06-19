## Plan

1. **Fix the dropdown data fetch**
   - Replace the embedded `user_roles -> profiles` query that is failing because the backend has no direct relationship between those tables.
   - Fetch `user_roles` for `role = 'worker'`, then fetch matching `profiles` by `user_id`, and merge them in the frontend.

2. **Keep the existing role mapping**
   - Continue treating users with the existing `worker` role as the selectable “Production Manager” recipients.
   - Do not create a new `production_manager` role.

3. **Verify the dropdown**
   - Confirm the Production Manager select now receives names from profiles and no longer shows “No production managers available.”

## Technical details

The current request fails with:

```text
Could not find a relationship between 'user_roles' and 'profiles' in the schema cache
```

So the issue is not missing data. The live database has worker users with profile names, but this frontend query is invalid:

```ts
supabase.from("user_roles").select("user_id, profiles!inner(name)").eq("role", "worker")
```

I’ll change only `src/pages/admin/StockManagement.tsx` to use two plain queries and map by `user_id`.