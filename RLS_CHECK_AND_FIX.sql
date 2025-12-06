-- ============================================================================
-- CHECK RLS STATUS AND POLICIES
-- ============================================================================

-- Step 1: Check if RLS is enabled on receiving_records
SELECT 
  tablename,
  CASE WHEN rowsecurity THEN 'ENABLED ✅' ELSE 'DISABLED ❌' END as rls_status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'receiving_records';

-- Step 2: Check all policies
SELECT 
  policyname,
  cmd as "Operation",
  permissive,
  qual as "USING_clause",
  with_check as "WITH_CHECK_clause"
FROM pg_policies
WHERE tablename = 'receiving_records'
ORDER BY policyname;

-- Step 3: If RLS is disabled, enable it
ALTER TABLE receiving_records ENABLE ROW LEVEL SECURITY;

-- Step 4: Drop all existing policies
DROP POLICY IF EXISTS "allow_all_operations" ON receiving_records;
DROP POLICY IF EXISTS "authenticated_users_full_access" ON receiving_records;
DROP POLICY IF EXISTS "anon_full_access" ON receiving_records;
DROP POLICY IF EXISTS "Allow anon insert receiving_records" ON receiving_records;
DROP POLICY IF EXISTS "Users can delete their own receiving records" ON receiving_records;
DROP POLICY IF EXISTS "Users can insert receiving records" ON receiving_records;
DROP POLICY IF EXISTS "Users can update receiving records" ON receiving_records;
DROP POLICY IF EXISTS "authenticated_insert" ON receiving_records;
DROP POLICY IF EXISTS "authenticated_update" ON receiving_records;
DROP POLICY IF EXISTS "authenticated_delete" ON receiving_records;

-- Step 5: Create ONE simple policy - allow everything
CREATE POLICY "allow_everything" ON receiving_records 
  FOR ALL 
  USING (true)
  WITH CHECK (true);

-- Step 6: Verify
SELECT 
  tablename,
  CASE WHEN rowsecurity THEN 'RLS ENABLED ✅' ELSE 'RLS DISABLED ❌' END as status
FROM pg_tables
WHERE tablename = 'receiving_records';

SELECT 
  policyname,
  cmd,
  qual as "USING",
  with_check as "WITH_CHECK"
FROM pg_policies
WHERE tablename = 'receiving_records';

-- ============================================================================
-- If you still get 401 after this, the problem is NOT RLS
-- It could be:
-- 1. Column permissions
-- 2. Supabase REST API restrictions
-- 3. Network/CORS issues
-- 4. Something else in the application
-- ============================================================================
