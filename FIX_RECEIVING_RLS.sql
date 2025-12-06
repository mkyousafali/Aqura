-- Fix RLS for receiving_records - ensure INSERT is completely allowed
-- First, drop the existing allow_all_operations policy if it exists
DROP POLICY IF EXISTS "allow_all_operations" ON receiving_records;

-- Create a more explicit INSERT policy
CREATE POLICY "allow_insert_receiving" ON receiving_records
  FOR INSERT
  WITH CHECK (true);

-- Ensure SELECT is allowed
DROP POLICY IF EXISTS "allow_select_receiving" ON receiving_records;
CREATE POLICY "allow_select_receiving" ON receiving_records
  FOR SELECT
  USING (true);

-- Ensure UPDATE is allowed
DROP POLICY IF EXISTS "allow_update_receiving" ON receiving_records;
CREATE POLICY "allow_update_receiving" ON receiving_records
  FOR UPDATE
  WITH CHECK (true);

-- Ensure DELETE is allowed
DROP POLICY IF EXISTS "allow_delete_receiving" ON receiving_records;
CREATE POLICY "allow_delete_receiving" ON receiving_records
  FOR DELETE
  USING (true);

-- Verify the policies
SELECT 
  policyname, 
  action,
  permissive,
  qual as using_clause,
  with_check
FROM pg_policies 
WHERE tablename = 'receiving_records'
ORDER BY action;
