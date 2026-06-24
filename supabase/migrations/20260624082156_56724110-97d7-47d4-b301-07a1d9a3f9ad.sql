ALTER TABLE public.stock_issues
  ADD COLUMN IF NOT EXISTS product_code_id uuid,
  ADD COLUMN IF NOT EXISTS raw_material_id uuid,
  ADD COLUMN IF NOT EXISTS quantity numeric,
  ADD COLUMN IF NOT EXISTS unit text,
  ADD COLUMN IF NOT EXISTS issue_quantity numeric,
  ADD COLUMN IF NOT EXISTS issue_unit text,
  ADD COLUMN IF NOT EXISTS issue_quantity_kg numeric,
  ADD COLUMN IF NOT EXISTS issue_quantity_sqm numeric,
  ADD COLUMN IF NOT EXISTS recipient_user_id uuid,
  ADD COLUMN IF NOT EXISTS issued_to_user_id uuid,
  ADD COLUMN IF NOT EXISTS recipient_type text,
  ADD COLUMN IF NOT EXISTS thickness_mm numeric,
  ADD COLUMN IF NOT EXISTS gsm numeric,
  ADD COLUMN IF NOT EXISTS notes text;

UPDATE public.stock_issues SET quantity = issue_quantity WHERE quantity IS NULL AND issue_quantity IS NOT NULL;
UPDATE public.stock_issues SET issue_quantity = quantity WHERE issue_quantity IS NULL AND quantity IS NOT NULL;
UPDATE public.stock_issues SET unit = issue_unit WHERE unit IS NULL AND issue_unit IS NOT NULL;
UPDATE public.stock_issues SET issue_unit = unit WHERE issue_unit IS NULL AND unit IS NOT NULL;
UPDATE public.stock_issues SET recipient_user_id = issued_to_user_id WHERE recipient_user_id IS NULL AND issued_to_user_id IS NOT NULL;
UPDATE public.stock_issues SET issued_to_user_id = recipient_user_id WHERE issued_to_user_id IS NULL AND recipient_user_id IS NOT NULL;

NOTIFY pgrst, 'reload schema';