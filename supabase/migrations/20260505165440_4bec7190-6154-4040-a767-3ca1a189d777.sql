
CREATE POLICY "Workers can update own entries"
ON public.production_entries
FOR UPDATE
USING (auth.uid() = worker_id)
WITH CHECK (auth.uid() = worker_id);

CREATE POLICY "Workers can delete own entries"
ON public.production_entries
FOR DELETE
USING (auth.uid() = worker_id);
