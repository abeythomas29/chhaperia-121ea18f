ALTER TABLE public.slitting_entries
  ADD COLUMN IF NOT EXISTS client_id uuid,
  ADD COLUMN IF NOT EXISTS gsm numeric,
  ADD COLUMN IF NOT EXISTS thickness_mm numeric;

DO $$
BEGIN
  IF to_regclass('public.company_clients') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1
       FROM pg_constraint
       WHERE conname = 'slitting_entries_client_id_fkey'
         AND conrelid = 'public.slitting_entries'::regclass
     ) THEN
    ALTER TABLE public.slitting_entries
      ADD CONSTRAINT slitting_entries_client_id_fkey
      FOREIGN KEY (client_id)
      REFERENCES public.company_clients(id)
      ON DELETE SET NULL;
  END IF;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_slitting_entries_client_id
  ON public.slitting_entries(client_id);

NOTIFY pgrst, 'reload schema';