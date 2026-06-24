ALTER TABLE public.raw_material_stock_entries
  ADD COLUMN IF NOT EXISTS entry_type text NOT NULL DEFAULT 'inward';

UPDATE public.raw_material_stock_entries SET entry_type = 'inward' WHERE entry_type IS NULL;

ALTER TABLE public.raw_material_stock_entries
  DROP CONSTRAINT IF EXISTS raw_material_stock_entries_entry_type_check;

ALTER TABLE public.raw_material_stock_entries
  ADD CONSTRAINT raw_material_stock_entries_entry_type_check
  CHECK (entry_type IN ('inward', 'issue', 'adjustment'));

NOTIFY pgrst, 'reload schema';