-- Comprehensive RLS fix for system_api_keys
-- Issue: Policy restricted to public role, blocking anon/authenticated access

-- Step 1: Disable RLS temporarily to fix policies
ALTER TABLE public.system_api_keys DISABLE ROW LEVEL SECURITY;

-- Step 2: Drop all existing policies
DROP POLICY IF EXISTS "Allow all access to system_api_keys" ON public.system_api_keys;

-- Step 3: Re-enable RLS
ALTER TABLE public.system_api_keys ENABLE ROW LEVEL SECURITY;

-- Step 4: Create permissive policy (this applies to ALL roles by default in permissive mode)
CREATE POLICY "Enable all access to system_api_keys"
  ON public.system_api_keys
  AS PERMISSIVE
  FOR ALL
  TO public  -- This means "all authenticated users" in Supabase context
  USING (true)
  WITH CHECK (true);

-- Step 5: Verify policy was created
\echo 'Policy created:'
SELECT policyname, permissive, roles, qual, with_check FROM pg_policies WHERE tablename = 'system_api_keys';

-- Step 6: Verify grants exist for anon and authenticated
\echo ''
\echo 'Grants on system_api_keys:'
SELECT grantee, string_agg(privilege_type, ', ') as privileges FROM information_schema.table_privileges 
WHERE table_name = 'system_api_keys' AND table_schema = 'public' 
GROUP BY grantee ORDER BY grantee;

-- Step 7: Show some data to verify table is accessible
\echo ''
\echo 'Sample data from system_api_keys:'
SELECT id, service_name, is_active FROM public.system_api_keys LIMIT 10;
