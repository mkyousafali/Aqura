-- Enable RLS on employee_checklist_assignments with permissive policies

-- Enable RLS (Row Level Security)
ALTER TABLE employee_checklist_assignments ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to employee_checklist_assignments" ON employee_checklist_assignments;
DROP POLICY IF EXISTS "Users can view assignments for their branch" ON employee_checklist_assignments;
DROP POLICY IF EXISTS "Users can insert assignments for their branch" ON employee_checklist_assignments;
DROP POLICY IF EXISTS "Users can update assignments for their branch" ON employee_checklist_assignments;
DROP POLICY IF EXISTS "Users can soft delete assignments for their branch" ON employee_checklist_assignments;
DROP POLICY IF EXISTS "Allow authenticated users full access" ON employee_checklist_assignments;

-- Simple permissive policy for all operations (matching pattern from denomination_user_preferences)
CREATE POLICY "Allow all access to employee_checklist_assignments"
  ON employee_checklist_assignments
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON employee_checklist_assignments TO authenticated;
GRANT ALL ON employee_checklist_assignments TO service_role;
GRANT ALL ON employee_checklist_assignments TO anon;
