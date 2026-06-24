
ALTER TABLE public.stock_issues
  ADD COLUMN IF NOT EXISTS issue_type text NOT NULL DEFAULT 'finished_stock',
  ADD COLUMN IF NOT EXISTS raw_material_id uuid;

UPDATE public.stock_issues SET issue_type = 'finished_stock' WHERE issue_type IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'stock_issues_raw_material_id_fkey'
      AND conrelid = 'public.stock_issues'::regclass
  ) THEN
    ALTER TABLE public.stock_issues
      ADD CONSTRAINT stock_issues_raw_material_id_fkey
      FOREIGN KEY (raw_material_id) REFERENCES public.raw_materials(id);
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'stock_issues_issue_type_check' AND conrelid = 'public.stock_issues'::regclass) THEN
    ALTER TABLE public.stock_issues DROP CONSTRAINT stock_issues_issue_type_check;
  END IF;
  ALTER TABLE public.stock_issues
    ADD CONSTRAINT stock_issues_issue_type_check
    CHECK (issue_type IN ('finished_stock', 'raw_material'));
END $$;

ALTER TABLE public.slitting_entries
  ADD COLUMN IF NOT EXISTS stock_issue_id uuid,
  ADD COLUMN IF NOT EXISTS source_quantity numeric;

DO $$
BEGIN
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

DROP FUNCTION IF EXISTS public.list_stock_issues();
DROP FUNCTION IF EXISTS public.list_slitting_issued_materials();

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
  recipient_type text,
  recipient_user_id uuid,
  recipient_name text,
  issued_by uuid,
  issued_by_name text,
  notes text,
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_privileged boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  v_privileged := public.is_admin(auth.uid())
    OR public.has_role(auth.uid(), 'inventory_manager');

  RETURN QUERY
  SELECT
    si.id,
    si.date,
    COALESCE(si.issue_type, 'finished_stock'),
    si.product_code_id,
    pc.code,
    si.raw_material_id,
    rm.name,
    si.quantity,
    si.unit,
    si.thickness_mm,
    NULL::numeric,
    si.client_id,
    cc.name,
    si.recipient_type,
    si.recipient_user_id,
    pr.name,
    si.issued_by,
    pb.name,
    si.notes,
    si.created_at
  FROM public.stock_issues si
  LEFT JOIN public.product_codes pc ON pc.id = si.product_code_id
  LEFT JOIN public.raw_materials rm ON rm.id = si.raw_material_id
  LEFT JOIN public.company_clients cc ON cc.id = si.client_id
  LEFT JOIN public.profiles pr ON pr.user_id = si.recipient_user_id
  LEFT JOIN public.profiles pb ON pb.user_id = si.issued_by
  WHERE v_privileged OR si.recipient_user_id = auth.uid()
  ORDER BY si.date DESC, si.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_stock_issues() TO authenticated;

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
    si.id,
    si.raw_material_id,
    COALESCE(rm.name, ''),
    si.quantity,
    COALESCE(c.consumed, 0)::numeric,
    (si.quantity - COALESCE(c.consumed, 0))::numeric,
    si.unit,
    si.thickness_mm,
    NULL::numeric,
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
    AND si.recipient_user_id = auth.uid()
    AND (si.quantity - COALESCE(c.consumed, 0)) > 0
  ORDER BY si.date DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_slitting_issued_materials() TO authenticated;

NOTIFY pgrst, 'reload schema';
