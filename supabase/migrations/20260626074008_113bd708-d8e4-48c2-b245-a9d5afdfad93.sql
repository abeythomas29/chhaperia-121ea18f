
-- =========================================================================
-- Idempotent backend repair migration
-- Safe to re-run. No data deletion. No column drops/renames.
-- =========================================================================

-- ---------- stock_issues : columns ----------
ALTER TABLE public.stock_issues
  ADD COLUMN IF NOT EXISTS issue_type         text  DEFAULT 'finished_stock',
  ADD COLUMN IF NOT EXISTS product_code_id    uuid,
  ADD COLUMN IF NOT EXISTS product_code       text,
  ADD COLUMN IF NOT EXISTS raw_material_id    uuid,
  ADD COLUMN IF NOT EXISTS client_id          uuid,
  ADD COLUMN IF NOT EXISTS recipient_type     text,
  ADD COLUMN IF NOT EXISTS recipient_user_id  uuid,
  ADD COLUMN IF NOT EXISTS issued_to_user_id  uuid,
  ADD COLUMN IF NOT EXISTS issued_by          uuid,
  ADD COLUMN IF NOT EXISTS quantity           numeric,
  ADD COLUMN IF NOT EXISTS unit               text,
  ADD COLUMN IF NOT EXISTS issue_unit         text,
  ADD COLUMN IF NOT EXISTS issue_quantity     numeric,
  ADD COLUMN IF NOT EXISTS issue_quantity_kg  numeric,
  ADD COLUMN IF NOT EXISTS issue_quantity_sqm numeric,
  ADD COLUMN IF NOT EXISTS thickness_mm       numeric,
  ADD COLUMN IF NOT EXISTS gsm                numeric,
  ADD COLUMN IF NOT EXISTS lot_number         text,
  ADD COLUMN IF NOT EXISTS notes              text,
  ADD COLUMN IF NOT EXISTS date               date  DEFAULT CURRENT_DATE;

-- ---------- stock_issues : check constraints (rebuild to current contract) ----------
ALTER TABLE public.stock_issues DROP CONSTRAINT IF EXISTS stock_issues_issue_type_check;
ALTER TABLE public.stock_issues
  ADD CONSTRAINT stock_issues_issue_type_check
  CHECK (issue_type = ANY (ARRAY['finished_stock','raw_material']));

ALTER TABLE public.stock_issues DROP CONSTRAINT IF EXISTS stock_issues_item_check;
ALTER TABLE public.stock_issues
  ADD CONSTRAINT stock_issues_item_check
  CHECK (
    (issue_type = 'finished_stock' AND product_code_id IS NOT NULL)
    OR (issue_type = 'raw_material' AND raw_material_id IS NOT NULL)
  );

ALTER TABLE public.stock_issues DROP CONSTRAINT IF EXISTS stock_issues_recipient_check;
ALTER TABLE public.stock_issues
  ADD CONSTRAINT stock_issues_recipient_check
  CHECK (
    recipient_type IS NULL
    OR (recipient_type = 'client' AND client_id IS NOT NULL)
    OR (
      recipient_type = ANY (ARRAY['internal_manager','production_manager','slitting_manager','worker','inventory_manager'])
      AND (recipient_user_id IS NOT NULL OR issued_to_user_id IS NOT NULL)
    )
  );

-- ---------- stock_issues : FKs (idempotent) ----------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stock_issues_product_code_id_fkey') THEN
    ALTER TABLE public.stock_issues
      ADD CONSTRAINT stock_issues_product_code_id_fkey
      FOREIGN KEY (product_code_id) REFERENCES public.product_codes(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stock_issues_raw_material_id_fkey') THEN
    ALTER TABLE public.stock_issues
      ADD CONSTRAINT stock_issues_raw_material_id_fkey
      FOREIGN KEY (raw_material_id) REFERENCES public.raw_materials(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stock_issues_client_id_fkey') THEN
    ALTER TABLE public.stock_issues
      ADD CONSTRAINT stock_issues_client_id_fkey
      FOREIGN KEY (client_id) REFERENCES public.company_clients(id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stock_issues_issued_by_profiles_fkey') THEN
    ALTER TABLE public.stock_issues
      ADD CONSTRAINT stock_issues_issued_by_profiles_fkey
      FOREIGN KEY (issued_by) REFERENCES public.profiles(user_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stock_issues_issued_to_user_id_fkey') THEN
    ALTER TABLE public.stock_issues
      ADD CONSTRAINT stock_issues_issued_to_user_id_fkey
      FOREIGN KEY (issued_to_user_id) REFERENCES public.profiles(user_id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stock_issues_recipient_user_id_fkey') THEN
    ALTER TABLE public.stock_issues
      ADD CONSTRAINT stock_issues_recipient_user_id_fkey
      FOREIGN KEY (recipient_user_id) REFERENCES public.profiles(user_id) ON DELETE SET NULL;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_stock_issues_recipient_user ON public.stock_issues(recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_stock_issues_issued_to_user ON public.stock_issues(issued_to_user_id);
CREATE INDEX IF NOT EXISTS idx_stock_issues_raw_material   ON public.stock_issues(raw_material_id);
CREATE INDEX IF NOT EXISTS idx_stock_issues_product_code   ON public.stock_issues(product_code_id);
CREATE INDEX IF NOT EXISTS idx_stock_issues_client         ON public.stock_issues(client_id);
CREATE INDEX IF NOT EXISTS idx_stock_issues_issue_type     ON public.stock_issues(issue_type);

-- ---------- stock_issues : recipient sync trigger (idempotent) ----------
CREATE OR REPLACE FUNCTION public.sync_stock_issues_recipient()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.issued_to_user_id IS NULL AND NEW.recipient_user_id IS NOT NULL THEN
    NEW.issued_to_user_id := NEW.recipient_user_id;
  ELSIF NEW.recipient_user_id IS NULL AND NEW.issued_to_user_id IS NOT NULL THEN
    NEW.recipient_user_id := NEW.issued_to_user_id;
  END IF;
  RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS trg_sync_stock_issues_recipient ON public.stock_issues;
CREATE TRIGGER trg_sync_stock_issues_recipient
BEFORE INSERT OR UPDATE ON public.stock_issues
FOR EACH ROW EXECUTE FUNCTION public.sync_stock_issues_recipient();

-- ---------- raw_material_stock_entries : columns ----------
ALTER TABLE public.raw_material_stock_entries
  ADD COLUMN IF NOT EXISTS entry_type        text    NOT NULL DEFAULT 'inward',
  ADD COLUMN IF NOT EXISTS entry_kind        text    NOT NULL DEFAULT 'in',
  ADD COLUMN IF NOT EXISTS lot_number        text,
  ADD COLUMN IF NOT EXISTS supplier          text,
  ADD COLUMN IF NOT EXISTS pallets           numeric,
  ADD COLUMN IF NOT EXISTS thickness_mm      numeric,
  ADD COLUMN IF NOT EXISTS gsm               numeric,
  ADD COLUMN IF NOT EXISTS issue_unit        text,
  ADD COLUMN IF NOT EXISTS issue_quantity    numeric,
  ADD COLUMN IF NOT EXISTS issued_to_user_id uuid;

-- entry_type check: allow inward / issue / adjustment
ALTER TABLE public.raw_material_stock_entries
  DROP CONSTRAINT IF EXISTS raw_material_stock_entries_entry_type_check;
ALTER TABLE public.raw_material_stock_entries
  ADD CONSTRAINT raw_material_stock_entries_entry_type_check
  CHECK (entry_type = ANY (ARRAY['inward','issue','adjustment']));

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'raw_material_stock_entries_issued_to_user_fk') THEN
    ALTER TABLE public.raw_material_stock_entries
      ADD CONSTRAINT raw_material_stock_entries_issued_to_user_fk
      FOREIGN KEY (issued_to_user_id) REFERENCES public.profiles(user_id) ON DELETE SET NULL;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_rmse_raw_material ON public.raw_material_stock_entries(raw_material_id);
CREATE INDEX IF NOT EXISTS idx_rmse_entry_type   ON public.raw_material_stock_entries(entry_type);
CREATE INDEX IF NOT EXISTS idx_rmse_issued_to    ON public.raw_material_stock_entries(issued_to_user_id);

-- ---------- slitting_entries : stock_issue_id ----------
ALTER TABLE public.slitting_entries
  ADD COLUMN IF NOT EXISTS stock_issue_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'slitting_entries_stock_issue_id_fkey') THEN
    ALTER TABLE public.slitting_entries
      ADD CONSTRAINT slitting_entries_stock_issue_id_fkey
      FOREIGN KEY (stock_issue_id) REFERENCES public.stock_issues(id) ON DELETE SET NULL;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_slitting_entries_stock_issue ON public.slitting_entries(stock_issue_id);

-- ---------- raw_material_usage : optional stock_issue_id ----------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema='public' AND table_name='raw_material_usage') THEN
    EXECUTE 'ALTER TABLE public.raw_material_usage ADD COLUMN IF NOT EXISTS stock_issue_id uuid';
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'raw_material_usage_stock_issue_id_fkey') THEN
      EXECUTE 'ALTER TABLE public.raw_material_usage
               ADD CONSTRAINT raw_material_usage_stock_issue_id_fkey
               FOREIGN KEY (stock_issue_id) REFERENCES public.stock_issues(id) ON DELETE SET NULL';
    END IF;
    EXECUTE 'CREATE INDEX IF NOT EXISTS idx_rmu_stock_issue ON public.raw_material_usage(stock_issue_id)';
  END IF;
END$$;

-- ---------- stock_issues : RLS policies (clean rebuild) ----------
ALTER TABLE public.stock_issues ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage stock issues"   ON public.stock_issues;
DROP POLICY IF EXISTS "Workers can insert stock issues"  ON public.stock_issues;
DROP POLICY IF EXISTS "Workers can view stock issues"    ON public.stock_issues;
DROP POLICY IF EXISTS "Privileged can manage stock issues" ON public.stock_issues;
DROP POLICY IF EXISTS "Recipients can view own stock issues" ON public.stock_issues;
DROP POLICY IF EXISTS "Users can insert stock issues as issuer" ON public.stock_issues;

CREATE POLICY "Privileged can manage stock issues"
  ON public.stock_issues FOR ALL
  TO authenticated
  USING (public.is_admin(auth.uid()) OR public.has_role(auth.uid(), 'inventory_manager'))
  WITH CHECK (public.is_admin(auth.uid()) OR public.has_role(auth.uid(), 'inventory_manager'));

CREATE POLICY "Recipients can view own stock issues"
  ON public.stock_issues FOR SELECT
  TO authenticated
  USING (
    auth.uid() = recipient_user_id
    OR auth.uid() = issued_to_user_id
    OR auth.uid() = issued_by
    OR public.is_admin(auth.uid())
    OR public.has_role(auth.uid(), 'inventory_manager')
  );

CREATE POLICY "Users can insert stock issues as issuer"
  ON public.stock_issues FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = issued_by
    OR public.is_admin(auth.uid())
    OR public.has_role(auth.uid(), 'inventory_manager')
  );

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
