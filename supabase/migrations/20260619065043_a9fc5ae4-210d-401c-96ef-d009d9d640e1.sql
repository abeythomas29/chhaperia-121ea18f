ALTER TABLE public.raw_material_stock_entries
ADD COLUMN IF NOT EXISTS gsm NUMERIC;

NOTIFY pgrst, 'reload schema';