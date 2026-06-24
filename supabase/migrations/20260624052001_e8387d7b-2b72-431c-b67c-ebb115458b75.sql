
-- 1. Add columns to stock_issues (idempotent)
ALTER TABLE public.stock_issues
  ADD COLUMN IF NOT EXISTS issue_type text,
  ADD COLUMN IF NOT EXISTS raw_material_id uuid,
  ADD COLUMN IF NOT EXISTS product_code text;

-- FK for raw_material_id
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'stock_issues_raw_material_id_fkey'
  ) THEN
    ALTER TABLE public.stock_issues
      ADD CONSTRAINT stock_issues_raw_material_id_fkey
      FOREIGN KEY (raw_material_id) REFERENCES public.raw_materials(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Backfill issue_type
UPDATE public.stock_issues
  SET issue_type = 'raw_material'
  WHERE issue_type IS NULL AND raw_material_id IS NOT NULL;
UPDATE public.stock_issues
  SET issue_type = 'finished_stock'
  WHERE issue_type IS NULL;

-- Default for future rows
ALTER TABLE public.stock_issues
  ALTER COLUMN issue_type SET DEFAULT 'finished_stock';

-- issue_type check
ALTER TABLE public.stock_issues DROP CONSTRAINT IF EXISTS stock_issues_issue_type_check;
ALTER TABLE public.stock_issues
  ADD CONSTRAINT stock_issues_issue_type_check
  CHECK (issue_type IN ('finished_stock','raw_material'));

-- Allow raw material issues (no product_code_id required)
ALTER TABLE public.stock_issues ALTER COLUMN product_code_id DROP NOT NULL;

-- Ensure one of the two product references is present
ALTER TABLE public.stock_issues DROP CONSTRAINT IF EXISTS stock_issues_item_check;
ALTER TABLE public.stock_issues
  ADD CONSTRAINT stock_issues_item_check
  CHECK (
    (issue_type = 'finished_stock' AND product_code_id IS NOT NULL)
    OR (issue_type = 'raw_material' AND raw_material_id IS NOT NULL)
  );

-- 2. Sync trigger for recipient_user_id <-> issued_to_user_id
CREATE OR REPLACE FUNCTION public.sync_stock_issues_recipient()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.issued_to_user_id IS NULL AND NEW.recipient_user_id IS NOT NULL THEN
    NEW.issued_to_user_id := NEW.recipient_user_id;
  ELSIF NEW.recipient_user_id IS NULL AND NEW.issued_to_user_id IS NOT NULL THEN
    NEW.recipient_user_id := NEW.issued_to_user_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_stock_issues_recipient ON public.stock_issues;
CREATE TRIGGER trg_sync_stock_issues_recipient
  BEFORE INSERT OR UPDATE ON public.stock_issues
  FOR EACH ROW EXECUTE FUNCTION public.sync_stock_issues_recipient();

-- Backfill mismatches
UPDATE public.stock_issues
  SET issued_to_user_id = recipient_user_id
  WHERE issued_to_user_id IS NULL AND recipient_user_id IS NOT NULL;
UPDATE public.stock_issues
  SET recipient_user_id = issued_to_user_id
  WHERE recipient_user_id IS NULL AND issued_to_user_id IS NOT NULL;

-- 3. Link slitting_entries to stock_issues for consumption tracking
ALTER TABLE public.slitting_entries
  ADD COLUMN IF NOT EXISTS stock_issue_id uuid;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'slitting_entries_stock_issue_id_fkey'
  ) THEN
    ALTER TABLE public.slitting_entries
      ADD CONSTRAINT slitting_entries_stock_issue_id_fkey
      FOREIGN KEY (stock_issue_id) REFERENCES public.stock_issues(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 4. RPC: pending raw material issues for the logged-in slitting manager
CREATE OR REPLACE FUNCTION public.list_slitting_issued_materials()
RETURNS TABLE(
  stock_issue_id uuid,
  raw_material_id uuid,
  material_name text,
  issued_quantity numeric,
  consumed_quantity numeric,
  remaining_quantity numeric,
  unit text,
  thickness_mm numeric,
  gsm numeric,
  notes text,
  date date
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    si.id AS stock_issue_id,
    si.raw_material_id,
    COALESCE(rm.name, '') AS material_name,
    si.quantity AS issued_quantity,
    COALESCE(c.consumed, 0)::numeric AS consumed_quantity,
    (si.quantity - COALESCE(c.consumed, 0))::numeric AS remaining_quantity,
    si.unit,
    si.thickness_mm,
    si.gsm,
    si.notes,
    si.date
  FROM public.stock_issues si
  LEFT JOIN public.raw_materials rm ON rm.id = si.raw_material_id
  LEFT JOIN (
    SELECT stock_issue_id, SUM(source_quantity) AS consumed
    FROM public.slitting_entries
    WHERE stock_issue_id IS NOT NULL
    GROUP BY stock_issue_id
  ) c ON c.stock_issue_id = si.id
  WHERE si.issue_type = 'raw_material'
    AND (si.issued_to_user_id = auth.uid() OR si.recipient_user_id = auth.uid())
    AND (si.quantity - COALESCE(c.consumed, 0)) > 0
  ORDER BY si.date DESC;
END;
$$;

-- 5. RPC: combined issue history for admin / inventory_manager
CREATE OR REPLACE FUNCTION public.list_stock_issues()
RETURNS TABLE(
  id uuid,
  date date,
  issue_type text,
  product_code_id uuid,
  product_code text,
  raw_material_id uuid,
  raw_material_name text,
  quantity numeric,
  unit text,
  thickness_mm numeric,
  gsm numeric,
  client_id uuid,
  client_name text,
  issued_to_user_id uuid,
  recipient_name text,
  recipient_type text,
  issued_by uuid,
  issued_by_name text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;
  IF NOT (
    public.is_admin(auth.uid())
    OR public.has_role(auth.uid(), 'inventory_manager')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  RETURN QUERY
  SELECT
    si.id,
    si.date,
    COALESCE(si.issue_type, 'finished_stock') AS issue_type,
    si.product_code_id,
    COALESCE(pc.code, si.product_code) AS product_code,
    si.raw_material_id,
    rm.name AS raw_material_name,
    si.quantity,
    si.unit,
    si.thickness_mm,
    si.gsm,
    si.client_id,
    cc.name AS client_name,
    COALESCE(si.issued_to_user_id, si.recipient_user_id) AS issued_to_user_id,
    pr.name AS recipient_name,
    si.recipient_type,
    si.issued_by,
    pb.name AS issued_by_name,
    si.notes,
    si.created_at
  FROM public.stock_issues si
  LEFT JOIN public.product_codes pc ON pc.id = si.product_code_id
  LEFT JOIN public.raw_materials rm ON rm.id = si.raw_material_id
  LEFT JOIN public.company_clients cc ON cc.id = si.client_id
  LEFT JOIN public.profiles pr ON pr.user_id = COALESCE(si.issued_to_user_id, si.recipient_user_id)
  LEFT JOIN public.profiles pb ON pb.user_id = si.issued_by
  ORDER BY si.date DESC, si.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_slitting_issued_materials() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_stock_issues() TO authenticated;

NOTIFY pgrst, 'reload schema';
