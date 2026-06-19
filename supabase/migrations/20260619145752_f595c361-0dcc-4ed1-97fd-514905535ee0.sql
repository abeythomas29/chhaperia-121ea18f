ALTER TABLE public.stock_issues ALTER COLUMN client_id DROP NOT NULL;
ALTER TABLE public.stock_issues ADD COLUMN IF NOT EXISTS issued_to_user_id uuid REFERENCES public.profiles(user_id) ON DELETE SET NULL;
ALTER TABLE public.stock_issues ADD CONSTRAINT stock_issues_recipient_check CHECK (client_id IS NOT NULL OR issued_to_user_id IS NOT NULL);
NOTIFY pgrst, 'reload schema';