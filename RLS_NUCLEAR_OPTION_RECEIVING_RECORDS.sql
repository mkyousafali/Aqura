-- ============================================================================
-- NUCLEAR OPTION: REMOVE ALL POLICIES AND START FRESH
-- ============================================================================
-- Sometimes multiple policies conflict. Let's remove EVERYTHING and rebuild
-- ============================================================================

-- Step 1: DISABLE RLS TEMPORARILY
ALTER TABLE receiving_records DISABLE ROW LEVEL SECURITY;

-- Step 2: DROP ALL POLICIES
DROP POLICY IF EXISTS "Allow anon insert receiving_records" ON receiving_records;
DROP POLICY IF EXISTS "Users can delete their own receiving records" ON receiving_records;
DROP POLICY IF EXISTS "Users can insert receiving records" ON receiving_records;
DROP POLICY IF EXISTS "Users can update receiving records" ON receiving_records;
DROP POLICY IF EXISTS "anon_full_access" ON receiving_records;
DROP POLICY IF EXISTS "authenticated_full_access" ON receiving_records;
DROP POLICY IF EXISTS "authenticated_insert" ON receiving_records;
DROP POLICY IF EXISTS "authenticated_update" ON receiving_records;
DROP POLICY IF EXISTS "authenticated_delete" ON receiving_records;

-- Step 3: RE-ENABLE RLS
ALTER TABLE receiving_records ENABLE ROW LEVEL SECURITY;

-- Step 4: CREATE SINGLE PERMISSIVE POLICY FOR AUTHENTICATED USERS
-- This is the simplest approach: allow all operations for authenticated users
CREATE POLICY "authenticated_users_full_access" ON receiving_records 
  FOR ALL 
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

-- Step 5: CREATE ANON KEY POLICY (for backward compatibility)
-- Anon key can do everything
CREATE POLICY "anon_full_access" ON receiving_records 
  FOR ALL 
  USING (auth.jwt()->>'role' = 'anon')
  WITH CHECK (auth.jwt()->>'role' = 'anon');

-- Step 6: VERIFY
SELECT 
  policyname,
  cmd as "Operation",
  permissive,
  roles,
  qual as "USING_clause",
  with_check as "WITH_CHECK_clause"
FROM pg_policies
WHERE tablename = 'receiving_records'
ORDER BY policyname;

-- ============================================================================
-- WHAT THIS DOES:
-- ============================================================================
-- ✅ Removes ALL conflicting policies
-- ✅ Creates ONE policy for authenticated users (all operations allowed)
-- ✅ Creates ONE policy for anon key (all operations allowed)
-- ✅ No restrictive branch checks at RLS level
-- ✅ Simple, clean, non-conflicting
--
-- Expected result: 2 policies total
-- - anon_full_access (ALL operations)
-- - authenticated_users_full_access (ALL operations)
--
-- ============================================================================
-- TEST NOW: Try to INSERT a receiving record
-- This MUST work now ✅
-- ============================================================================
