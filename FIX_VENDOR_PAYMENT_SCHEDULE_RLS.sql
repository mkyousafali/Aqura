-- ============================================================================
-- FIX: Add allow_all_operations policy to vendor_payment_schedule
-- ============================================================================

-- Check current policies on vendor_payment_schedule
SELECT 
  policyname,
  cmd as "Operation",
  qual as "USING",
  with_check as "WITH_CHECK"
FROM pg_policies
WHERE tablename = 'vendor_payment_schedule'
ORDER BY policyname;

-- Drop existing policies if any
DROP POLICY IF EXISTS "allow_all_operations" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "anon_full_access" ON vendor_payment_schedule;
DROP POLICY IF EXISTS "authenticated_full_access" ON vendor_payment_schedule;

-- Make sure RLS is enabled
ALTER TABLE vendor_payment_schedule ENABLE ROW LEVEL SECURITY;

-- Create the allow_all_operations policy
CREATE POLICY "allow_all_operations" ON vendor_payment_schedule 
  FOR ALL 
  USING (true) 
  WITH CHECK (true);

-- Verify it was created
SELECT 
  policyname,
  cmd as "Operation",
  qual as "USING",
  with_check as "WITH_CHECK"
FROM pg_policies
WHERE tablename = 'vendor_payment_schedule';

-- ============================================================================
-- Also check and fix vendors and branches tables that are referenced in the trigger
-- ============================================================================

-- vendors table
DROP POLICY IF EXISTS "allow_all_operations" ON vendors;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_operations" ON vendors FOR ALL USING (true) WITH CHECK (true);

-- branches table
DROP POLICY IF EXISTS "allow_all_operations" ON branches;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "allow_all_operations" ON branches FOR ALL USING (true) WITH CHECK (true);

-- ============================================================================
-- NOW TEST THE INSERT AGAIN
-- The trigger should work because vendor_payment_schedule now allows all operations
-- ============================================================================
