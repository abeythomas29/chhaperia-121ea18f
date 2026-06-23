ALTER TABLE public.stock_issues
  ADD COLUMN IF NOT EXISTS recipient_type text,
  ADD COLUMN IF NOT EXISTS issued_to_user_id uuid,
  ADD COLUMN IF NOT EXISTS issue_unit text,
  ADD COLUMN IF NOT EXISTS issue_quantity numeric,
  ADD COLUMN IF NOT EXISTS issue_quantity_kg numeric,
  ADD COLUMN IF NOT EXISTS gsm numeric,
  ADD COLUMN IF NOT EXISTS thickness_mm numeric;

ALTER TABLE public.slitting_entries
  ADD COLUMN IF NOT EXISTS client_id uuid,
  ADD COLUMN IF NOT EXISTS gsm numeric,
  ADD COLUMN IF NOT EXISTS thickness_mm numeric;

NOTIFY pgrst, 'reload schema';