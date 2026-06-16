CREATE TABLE IF NOT EXISTS public.head36_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slitting_entry_id uuid,
  product_code_id uuid,
  rolls_taken numeric NOT NULL DEFAULT 0,
  rolls_produced numeric NOT NULL DEFAULT 0,
  roll_width_mm numeric,
  length_per_tape_mtr numeric,
  thickness_mm numeric,
  gsm numeric,
  unit text NOT NULL DEFAULT 'meters',
  total_quantity numeric GENERATED ALWAYS AS (
    COALESCE(rolls_produced, 0) * COALESCE(length_per_tape_mtr, 0)
  ) STORED,
  date date NOT NULL DEFAULT CURRENT_DATE,
  operator_id uuid NOT NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.head36_entries TO authenticated;
GRANT ALL ON public.head36_entries TO service_role;

ALTER TABLE public.head36_entries ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='head36_entries' AND policyname='Admins can manage head36 entries') THEN
    CREATE POLICY "Admins can manage head36 entries"
      ON public.head36_entries FOR ALL
      USING (is_admin(auth.uid()));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='head36_entries' AND policyname='Authenticated can view head36 entries') THEN
    CREATE POLICY "Authenticated can view head36 entries"
      ON public.head36_entries FOR SELECT
      TO authenticated
      USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='head36_entries' AND policyname='Slitting managers can insert own head36 entries') THEN
    CREATE POLICY "Slitting managers can insert own head36 entries"
      ON public.head36_entries FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = operator_id AND has_role(auth.uid(), 'slitting_manager'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='head36_entries' AND policyname='Slitting managers can update own head36 entries') THEN
    CREATE POLICY "Slitting managers can update own head36 entries"
      ON public.head36_entries FOR UPDATE
      TO authenticated
      USING (auth.uid() = operator_id AND has_role(auth.uid(), 'slitting_manager'))
      WITH CHECK (auth.uid() = operator_id AND has_role(auth.uid(), 'slitting_manager'));
  END IF;
END $$;

DROP TRIGGER IF EXISTS update_head36_entries_updated_at ON public.head36_entries;
CREATE TRIGGER update_head36_entries_updated_at
  BEFORE UPDATE ON public.head36_entries
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

NOTIFY pgrst, 'reload schema';