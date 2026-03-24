-- Override: the previous migration 20260321014818 fails on prod because
-- total_quantity generated column blocks ALTER on rolls_count.
-- This migration ensures the schema is correct regardless of current state.
DO $$
BEGIN
  -- Drop total_quantity if it exists (handles generated or regular)
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'production_entries' AND column_name = 'total_quantity'
  ) THEN
    ALTER TABLE public.production_entries DROP COLUMN total_quantity;
  END IF;

  -- Ensure rolls_count is numeric
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'production_entries'
      AND column_name = 'rolls_count' AND data_type != 'numeric'
  ) THEN
    ALTER TABLE public.production_entries ALTER COLUMN rolls_count TYPE numeric USING rolls_count::numeric;
  END IF;

  -- Re-add total_quantity as generated column if missing
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'production_entries' AND column_name = 'total_quantity'
  ) THEN
    ALTER TABLE public.production_entries ADD COLUMN total_quantity numeric GENERATED ALWAYS AS (rolls_count * quantity_per_roll) STORED;
  END IF;
END $$;