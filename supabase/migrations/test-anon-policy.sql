-- Test: Create INSERT policy explicitly for anon role

DROP POLICY IF EXISTS "test_insert_anon" ON button_main_sections;
CREATE POLICY "test_insert_anon" ON button_main_sections
  FOR INSERT
  TO anon
  WITH CHECK (true);

-- Test the insert
-- This should work if the policy is correct
