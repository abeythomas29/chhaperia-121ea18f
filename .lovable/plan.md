## Goal
Add a "Client" column showing the client/company name to:
1. `src/pages/admin/ProductionLogs.tsx` — table at /admin/logs
2. `src/pages/admin/SlittingLogs.tsx` — table at /admin/slitting-logs

## Changes

### ProductionLogs.tsx
- Update Supabase select to embed client: `company_clients:client_id(name)` in both `fullSelect` and `basicSelect`.
- Extend `LogEntry` with `company_clients: { name: string } | null`.
- Insert a new `<TableHead>Client</TableHead>` after Product Code and a `<TableCell>{e.company_clients?.name ?? "—"}</TableCell>` in the same position.
- Add Client to CSV export header and rows.
- Update the table `colSpan` (currently 15) to match new column count.
- Include client name in search filter.

### SlittingLogs.tsx
- `slitting_entries` already has `client_id` (uuid, nullable). Update select to embed `company_clients:client_id(name)`.
- Extend `SlittingRow` with `company_clients: { name: string } | null`.
- Add a `Client` column header and cell after Product.
- Include client name in search filter.

## Out of scope
No DB schema changes, no edits to entry forms, no changes to other pages. Surgical column additions only.
