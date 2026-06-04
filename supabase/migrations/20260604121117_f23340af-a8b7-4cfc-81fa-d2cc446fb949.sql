
-- 1. Add missing production_entries columns (safe, additive)
ALTER TABLE public.production_entries
  ADD COLUMN IF NOT EXISTS gsm numeric,
  ADD COLUMN IF NOT EXISTS lab_report_included boolean,
  ADD COLUMN IF NOT EXISTS raw_material_included boolean;

-- 2. Create slitting_returns table
CREATE TABLE IF NOT EXISTS public.slitting_returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slitting_entry_id uuid NOT NULL REFERENCES public.slitting_entries(id) ON DELETE CASCADE,
  returned_quantity numeric NOT NULL DEFAULT 0,
  unit text NOT NULL DEFAULT 'meters',
  notes text,
  returned_by uuid NOT NULL,
  date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.slitting_returns TO authenticated;
GRANT ALL ON public.slitting_returns TO service_role;

ALTER TABLE public.slitting_returns ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='slitting_returns' AND policyname='Authenticated can view slitting returns') THEN
    CREATE POLICY "Authenticated can view slitting returns" ON public.slitting_returns FOR SELECT TO authenticated USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='slitting_returns' AND policyname='Slitting managers can insert own returns') THEN
    CREATE POLICY "Slitting managers can insert own returns" ON public.slitting_returns FOR INSERT TO authenticated
      WITH CHECK (auth.uid() = returned_by AND (public.has_role(auth.uid(),'slitting_manager') OR public.is_admin(auth.uid())));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='slitting_returns' AND policyname='Admins can manage slitting returns') THEN
    CREATE POLICY "Admins can manage slitting returns" ON public.slitting_returns FOR ALL TO authenticated
      USING (public.is_admin(auth.uid())) WITH CHECK (public.is_admin(auth.uid()));
  END IF;
END $$;

DROP TRIGGER IF EXISTS update_slitting_returns_updated_at ON public.slitting_returns;
CREATE TRIGGER update_slitting_returns_updated_at BEFORE UPDATE ON public.slitting_returns
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- 3. Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
