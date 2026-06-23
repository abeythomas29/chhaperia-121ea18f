ALTER TABLE public.stock_issues
  ADD COLUMN IF NOT EXISTS recipient_type text,
  ADD COLUMN IF NOT EXISTS recipient_user_id uuid,
  ADD COLUMN IF NOT EXISTS issued_to_user_id uuid;

UPDATE public.stock_issues
SET recipient_user_id = issued_to_user_id
WHERE recipient_user_id IS NULL AND issued_to_user_id IS NOT NULL;

UPDATE public.stock_issues
SET issued_to_user_id = recipient_user_id
WHERE issued_to_user_id IS NULL AND recipient_user_id IS NOT NULL;

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

NOTIFY pgrst, 'reload schema';