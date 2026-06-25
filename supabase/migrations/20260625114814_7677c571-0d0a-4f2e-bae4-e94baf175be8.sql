ALTER TABLE public.stock_issues
  ADD COLUMN IF NOT EXISTS lot_number text;

NOTIFY pgrst, 'reload schema';