CREATE POLICY "Managers can insert direct issue stock entries"
ON public.raw_material_stock_entries
FOR INSERT
TO authenticated
WITH CHECK (
  (has_role(auth.uid(), 'slitting_manager') OR has_role(auth.uid(), 'worker'))
  AND entry_type = 'issue'
  AND quantity > 0
  AND added_by = auth.uid()
);

NOTIFY pgrst, 'reload schema';