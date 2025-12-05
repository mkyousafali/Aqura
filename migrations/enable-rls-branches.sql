-- Enable RLS on branches table
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public (anon) users to SELECT all branches
CREATE POLICY "Allow public read branches"
ON public.branches
FOR SELECT
USING (true);

-- Policy: Allow authenticated users to INSERT branches
CREATE POLICY "Allow authenticated insert branches"
ON public.branches
FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Policy: Allow users to UPDATE their own branches (created_by)
CREATE POLICY "Allow users update own branches"
ON public.branches
FOR UPDATE
USING (
  (created_by::text = auth.uid()::text) 
  OR auth.role() = 'service_role'
)
WITH CHECK (
  (created_by::text = auth.uid()::text) 
  OR auth.role() = 'service_role'
);

-- Policy: Allow service role (backend) full access
CREATE POLICY "Service role full access branches"
ON public.branches
USING (auth.role() = 'service_role')
WITH CHECK (auth.role() = 'service_role');
