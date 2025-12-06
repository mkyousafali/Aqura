-- ============================================================================
-- RLS TEST FOR receiving_records TABLE ONLY
-- ============================================================================
-- Date: December 7, 2025
-- Purpose: Test RLS policy fix for INSERT operations on receiving_records
-- Strategy: Disable RLS, create policies with WITH CHECK, re-enable and test
-- ============================================================================

-- ============================================================================
-- STEP 1: DROP EXISTING POLICIES THAT ARE BLOCKING INSERT
-- ============================================================================
-- The problematic policies:
-- - "Users can update receiving records from their branch" (missing WITH CHECK)
-- - "Users can delete their own receiving records" (missing WITH CHECK)
-- These are blocking INSERT because they lack WITH CHECK clause
-- ============================================================================

DROP POLICY IF EXISTS "Users can update receiving records from their branch" ON receiving_records;
DROP POLICY IF EXISTS "Users can delete their own receiving records" ON receiving_records;

-- ============================================================================
-- STEP 2: RE-CREATE POLICIES WITH PROPER WITH CHECK CLAUSE FOR INSERT/UPDATE
-- ============================================================================

-- Policy: Users can INSERT and UPDATE receiving records from their branch
CREATE POLICY "Users can insert and update receiving records from their branch" ON receiving_records 
  FOR INSERT 
  WITH CHECK (
    branch_id IN (
      SELECT users.branch_id
      FROM users
      WHERE users.id = auth.uid()
    )
  );

CREATE POLICY "Users can update receiving records from their branch" ON receiving_records 
  FOR UPDATE 
  USING (
    branch_id IN (
      SELECT users.branch_id
      FROM users
      WHERE users.id = auth.uid()
    )
  )
  WITH CHECK (
    branch_id IN (
      SELECT users.branch_id
      FROM users
      WHERE users.id = auth.uid()
    )
  );

-- Policy: Users can delete their own receiving records
CREATE POLICY "Users can delete their own receiving records" ON receiving_records 
  FOR DELETE 
  USING (
    (user_id = auth.uid()) 
    AND (branch_id IN (
      SELECT users.branch_id
      FROM users
      WHERE users.id = auth.uid()
    ))
  );

-- ============================================================================
-- STEP 3: VERIFICATION QUERIES
-- ============================================================================

-- Check if RLS is enabled on receiving_records
SELECT 
  tablename,
  CASE WHEN rowsecurity THEN 'ENABLED ✅' ELSE 'DISABLED ❌' END as rls_status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'receiving_records';

-- List all policies on receiving_records with their details
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  qual as "USING_clause",
  with_check as "WITH_CHECK_clause"
FROM pg_policies
WHERE tablename = 'receiving_records'
ORDER BY policyname;

-- ============================================================================
-- STEP 4: EXPECTED TEST RESULTS
-- ============================================================================
-- Expected Policies After Fix:
-- 1. "Allow anon insert receiving_records" - PERMISSIVE, allows INSERT for anon
-- 2. "anon_full_access" - PERMISSIVE, allows all ops for anon role
-- 3. "authenticated_full_access" - PERMISSIVE, allows all ops for authenticated users
-- 4. "Users can delete their own receiving records" - DELETE only
-- 5. "Users can insert and update receiving records from their branch" - INSERT only
-- 6. "Users can update receiving records from their branch" - UPDATE only, with WITH CHECK
--
-- KEY FIX: Now INSERT and UPDATE both have WITH CHECK clauses
-- ============================================================================

-- ============================================================================
-- IMPORTANT NOTES FOR TESTING
-- ============================================================================
--
-- ROOT CAUSE: The existing policy "Users can update receiving records from their branch"
-- did NOT have a WITH CHECK clause. This blocks INSERT operations because PostgreSQL RLS
-- uses WITH CHECK for INSERT/UPDATE operations.
--
-- THE FIX:
-- 1. Separated UPDATE and INSERT into separate policies
-- 2. Added WITH CHECK clause to both
-- 3. Kept the branch_id validation logic
--
-- After running this SQL:
-- 1. Go to StartReceiving.svelte component
-- 2. Try to insert a receiving record
-- 3. Error should now be resolved ✅
--
-- If still getting 401 error:
-- - Check browser console for the exact error message
-- - Verify the user's branch_id matches the receiving record's branch_id
-- - Contact support with the exact error
--
-- ============================================================================
