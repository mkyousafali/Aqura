-- Disable RLS on branches table
-- Since using custom authentication (not Supabase Auth), disable RLS to allow data access
ALTER TABLE public.branches DISABLE ROW LEVEL SECURITY;

-- Drop existing policies (if you want to clean up)
-- DROP POLICY IF EXISTS "Allow public read branches" ON public.branches;
-- DROP POLICY IF EXISTS "Allow authenticated insert branches" ON public.branches;
-- DROP POLICY IF EXISTS "Allow users update own branches" ON public.branches;
-- DROP POLICY IF EXISTS "Service role full access branches" ON public.branches;
