
-- Extend raw_material_stock_entries to support material issues with unit conversion
ALTER TABLE public.raw_material_stock_entries
  ADD COLUMN IF NOT EXISTS entry_kind text NOT NULL DEFAULT 'in',
  ADD COLUMN IF NOT EXISTS issue_unit text,
  ADD COLUMN IF NOT EXISTS issue_quantity numeric,
  ADD COLUMN IF NOT EXISTS gsm numeric,
  ADD COLUMN IF NOT EXISTS issued_to_user_id uuid;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'raw_material_stock_entries_issued_to_user_fk'
  ) THEN
    ALTER TABLE public.raw_material_stock_entries
      ADD CONSTRAINT raw_material_stock_entries_issued_to_user_fk
      FOREIGN KEY (issued_to_user_id) REFERENCES public.profiles(user_id) ON DELETE SET NULL;
  END IF;
END$$;

CREATE INDEX IF NOT EXISTS idx_rmse_entry_kind ON public.raw_material_stock_entries(entry_kind);
CREATE INDEX IF NOT EXISTS idx_rmse_issued_to ON public.raw_material_stock_entries(issued_to_user_id);

-- Allow inventory managers (and admins already covered) to update/delete entries they manage
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'raw_material_stock_entries'
      AND policyname = 'Inventory managers can update stock entries'
  ) THEN
    CREATE POLICY "Inventory managers can update stock entries"
      ON public.raw_material_stock_entries
      FOR UPDATE
      TO authenticated
      USING (public.has_role(auth.uid(), 'inventory_manager') OR public.is_admin(auth.uid()))
      WITH CHECK (public.has_role(auth.uid(), 'inventory_manager') OR public.is_admin(auth.uid()));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'raw_material_stock_entries'
      AND policyname = 'Inventory managers can delete stock entries'
  ) THEN
    CREATE POLICY "Inventory managers can delete stock entries"
      ON public.raw_material_stock_entries
      FOR DELETE
      TO authenticated
      USING (public.has_role(auth.uid(), 'inventory_manager') OR public.is_admin(auth.uid()));
  END IF;
END$$;

NOTIFY pgrst, 'reload schema';
