-- ============================================================================
-- FINAL FIX: REMOVE RESTRICTIVE DELETE POLICY
-- ============================================================================
-- The "Users can delete their own receiving records" policy has a USING clause
-- that checks: branch_id IN (SELECT users.branch_id FROM users WHERE users.id = uid())
-- 
-- This USING clause is evaluated for ALL operations, not just DELETE
-- So it's blocking INSERT even though we have INSERT-specific policies
--
-- Solution: Drop this DELETE policy completely
-- ============================================================================

-- DROP the problematic DELETE policy
DROP POLICY IF EXISTS "Users can delete their own receiving records" ON receiving_records;

-- ============================================================================
-- VERIFICATION: Check remaining policies
-- ============================================================================

SELECT 
  policyname,
  cmd as "Operation",
  qual as "USING_clause",
  with_check as "WITH_CHECK_clause"
FROM pg_policies
WHERE tablename = 'receiving_records'
ORDER BY policyname;

-- ============================================================================
-- EXPECTED RESULT AFTER FIX:
-- ============================================================================
-- You should see:
-- 1. Allow anon insert receiving_records (INSERT)
-- 2. Users can insert receiving records (INSERT)  
-- 3. Users can update receiving records (UPDATE)
-- 4. anon_full_access (ALL)
-- 5. authenticated_full_access (ALL)
--
-- NO DELETE-specific policy with restrictive USING clause
-- ============================================================================

-- ============================================================================
-- TEST NOW:
-- Go to StartReceiving and try to insert - should work! ✅
-- ============================================================================
