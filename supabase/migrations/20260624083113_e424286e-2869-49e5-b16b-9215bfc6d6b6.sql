ALTER TABLE public.stock_issues
  ADD COLUMN IF NOT EXISTS issue_type text NOT NULL DEFAULT 'finished_stock',
  ADD COLUMN IF NOT EXISTS raw_material_id uuid,
  ADD COLUMN IF NOT EXISTS issue_quantity numeric,
  ADD COLUMN IF NOT EXISTS issue_unit text,
  ADD COLUMN IF NOT EXISTS issue_quantity_kg numeric,
  ADD COLUMN IF NOT EXISTS issue_quantity_sqm numeric,
  ADD COLUMN IF NOT EXISTS issued_to_user_id uuid,
  ADD COLUMN IF NOT EXISTS gsm numeric;

ALTER TABLE public.slitting_entries
  ADD COLUMN IF NOT EXISTS stock_issue_id uuid;

UPDATE public.stock_issues SET issue_quantity = quantity WHERE issue_quantity IS NULL AND quantity IS NOT NULL;
UPDATE public.stock_issues SET issue_unit = unit WHERE issue_unit IS NULL AND unit IS NOT NULL;
UPDATE public.stock_issues SET issued_to_user_id = recipient_user_id WHERE issued_to_user_id IS NULL AND recipient_user_id IS NOT NULL;
UPDATE public.stock_issues SET recipient_user_id = issued_to_user_id WHERE recipient_user_id IS NULL AND issued_to_user_id IS NOT NULL;
UPDATE public.stock_issues SET issue_type = 'finished_stock' WHERE issue_type IS NULL;

DO $$
BEGIN
  IF to_regclass('public.raw_materials') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM pg_constraint
       WHERE conname = 'stock_issues_raw_material_id_fkey'
         AND conrelid = 'public.stock_issues'::regclass
     ) THEN
    ALTER TABLE public.stock_issues
      ADD CONSTRAINT stock_issues_raw_material_id_fkey
      FOREIGN KEY (raw_material_id) REFERENCES public.raw_materials(id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'slitting_entries_stock_issue_id_fkey'
      AND conrelid = 'public.slitting_entries'::regclass
  ) THEN
    ALTER TABLE public.slitting_entries
      ADD CONSTRAINT slitting_entries_stock_issue_id_fkey
      FOREIGN KEY (stock_issue_id) REFERENCES public.stock_issues(id);
  END IF;
END $$;

ALTER TABLE public.stock_issues DROP CONSTRAINT IF EXISTS stock_issues_recipient_check;
ALTER TABLE public.stock_issues
  ADD CONSTRAINT stock_issues_recipient_check
  CHECK (
    recipient_type IS NULL
    OR (recipient_type = 'client' AND client_id IS NOT NULL)
    OR (
      recipient_type IN ('internal_manager', 'production_manager', 'slitting_manager', 'worker')
      AND (recipient_user_id IS NOT NULL OR issued_to_user_id IS NOT NULL)
    )
  );

CREATE INDEX IF NOT EXISTS idx_stock_issues_issue_type ON public.stock_issues(issue_type);
CREATE INDEX IF NOT EXISTS idx_stock_issues_raw_material_id ON public.stock_issues(raw_material_id);
CREATE INDEX IF NOT EXISTS idx_stock_issues_recipient_user_id ON public.stock_issues(recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_stock_issues_issued_to_user_id ON public.stock_issues(issued_to_user_id);
CREATE INDEX IF NOT EXISTS idx_slitting_entries_stock_issue_id ON public.slitting_entries(stock_issue_id);

NOTIFY pgrst, 'reload schema';