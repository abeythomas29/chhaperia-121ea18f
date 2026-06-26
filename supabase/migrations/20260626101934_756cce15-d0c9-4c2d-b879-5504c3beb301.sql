ALTER TABLE public.raw_material_stock_entries
  ADD COLUMN IF NOT EXISTS issue_quantity_kg numeric;

ALTER TABLE public.slitting_returns
  ADD COLUMN IF NOT EXISTS return_type text DEFAULT 'reusable',
  ADD COLUMN IF NOT EXISTS location text,
  ADD COLUMN IF NOT EXISTS wastage_quantity numeric;

ALTER TABLE public.slitting_returns
  DROP CONSTRAINT IF EXISTS slitting_returns_return_type_check;

ALTER TABLE public.slitting_returns
  ADD CONSTRAINT slitting_returns_return_type_check
  CHECK (return_type IN ('reusable', 'wastage'));

UPDATE public.slitting_returns
SET return_type = 'reusable'
WHERE return_type IS NULL;

NOTIFY pgrst, 'reload schema';