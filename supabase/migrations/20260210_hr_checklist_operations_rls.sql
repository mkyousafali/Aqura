-- Enable RLS on hr_checklist_operations with permissive policies
-- All authenticated users can perform all operations

ALTER TABLE hr_checklist_operations ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if exists
DROP POLICY IF EXISTS "Allow all access to hr_checklist_operations" ON hr_checklist_operations;

-- Create permissive policy for all operations
CREATE POLICY "Allow all access to hr_checklist_operations"
  ON hr_checklist_operations
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant permissions to roles
GRANT ALL ON hr_checklist_operations TO anon;
GRANT ALL ON hr_checklist_operations TO authenticated;
GRANT ALL ON hr_checklist_operations TO service_role;

-- Grant sequence permissions
GRANT USAGE, SELECT ON SEQUENCE hr_checklist_operations_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE hr_checklist_operations_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE hr_checklist_operations_id_seq TO service_role;
