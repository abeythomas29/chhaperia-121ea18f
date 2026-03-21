
-- Fix: ensure rolls_count is numeric and total_quantity is a stored generated column
-- This handles the case where the previous migration failed partway through

-- First drop total_quantity if it exists (whether generated or regular)
ALTER TABLE public.production_entries DROP COLUMN IF EXISTS total_quantity;

-- Now safely alter rolls_count to numeric
ALTER TABLE public.production_entries ALTER COLUMN rolls_count TYPE numeric USING rolls_count::numeric;

-- Recreate total_quantity as a stored generated column
ALTER TABLE public.production_entries ADD COLUMN total_quantity numeric GENERATED ALWAYS AS (rolls_count * quantity_per_roll) STORED;
