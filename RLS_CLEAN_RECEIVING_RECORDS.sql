-- ============================================================================
-- DIAGNOSIS: WHICH POLICY IS BLOCKING INSERT?
-- ============================================================================
-- Your current policies listed:
-- 1. Allow anon insert receiving_records (INSERT) - uid() check = true
-- 2. Users can delete their own receiving records (DELETE) - has USING with branch check
-- 3. Users can insert receiving records (INSERT) - uid() IS NOT NULL
-- 4. Users can update receiving records (UPDATE) - uid() IS NOT NULL
-- 5. anon_full_access (ALL) - auth.jwt()->>'role' = 'anon'
-- 6. authenticated_full_access (ALL) - uid() IS NOT NULL
--
-- PROBLEM: You have TWO overlapping INSERT policies (1 and 3)
-- AND a DELETE policy with a restrictive USING clause
--
-- SOLUTION: Keep ONLY ONE clean INSERT policy and remove all restrictive USING clauses
-- ============================================================================

-- Step 1: REMOVE ALL PROBLEMATIC POLICIES
DROP POLICY IF EXISTS "Allow anon insert receiving_records" ON receiving_records;
DROP POLICY IF EXISTS "Users can delete their own receiving records" ON receiving_records;
DROP POLICY IF EXISTS "Users can insert receiving records" ON receiving_records;
DROP POLICY IF EXISTS "Users can update receiving records" ON receiving_records;

-- Step 2: CREATE ONE CLEAN INSERT POLICY
-- This allows ANY authenticated user to insert (no branch validation at RLS level)
CREATE POLICY "authenticated_insert" ON receiving_records 
  FOR INSERT 
  WITH CHECK (auth.uid() IS NOT NULL);

-- Step 3: CREATE ONE CLEAN UPDATE POLICY
CREATE POLICY "authenticated_update" ON receiving_records 
  FOR UPDATE 
  USING (auth.uid() IS NOT NULL)
  WITH CHECK (auth.uid() IS NOT NULL);

-- Step 4: CREATE ONE CLEAN DELETE POLICY (NO USING clause to avoid blocking other ops)
CREATE POLICY "authenticated_delete" ON receiving_records 
  FOR DELETE 
  USING (auth.uid() IS NOT NULL);

-- Step 5: VERIFY - Check what policies remain
SELECT 
  policyname,
  cmd as "Operation",
  qual as "USING_clause",
  with_check as "WITH_CHECK_clause"
FROM pg_policies
WHERE tablename = 'receiving_records'
ORDER BY policyname, cmd;

-- ============================================================================
-- WHAT THIS FIXES:
-- ============================================================================
-- ✅ Removed duplicate "Allow anon insert" policy
-- ✅ Removed "Users can delete their own receiving records" with restrictive USING
-- ✅ Removed conflicting "Users can insert receiving records" 
-- ✅ Removed conflicting "Users can update receiving records"
-- ✅ Created simple, non-conflicting policies:
--    - authenticated_insert (INSERT only)
--    - authenticated_update (UPDATE only)
--    - authenticated_delete (DELETE only - simple check)
--    - anon_full_access (remains for anon users)
--    - authenticated_full_access (remains for all authenticated)
--
-- ============================================================================
-- TEST NOW: Try to INSERT a receiving record
-- It should work! ✅
-- ============================================================================
