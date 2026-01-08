-- Enable RLS on hr_employee_master table with permissive policies (matching denomination_user_preferences pattern)

-- Enable RLS (Row Level Security)
ALTER TABLE hr_employee_master ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "authenticated_can_view_hr_employee_master" ON hr_employee_master;
DROP POLICY IF EXISTS "authenticated_can_insert_hr_employee_master" ON hr_employee_master;
DROP POLICY IF EXISTS "authenticated_can_update_hr_employee_master" ON hr_employee_master;
DROP POLICY IF EXISTS "authenticated_can_delete_hr_employee_master" ON hr_employee_master;
DROP POLICY IF EXISTS "service_role_full_access_hr_employee_master" ON hr_employee_master;
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON hr_employee_master;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON hr_employee_master;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON hr_employee_master;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON hr_employee_master;
DROP POLICY IF EXISTS "service_role_full_access" ON hr_employee_master;
DROP POLICY IF EXISTS "Enable all access for hr_employee_master" ON hr_employee_master;
DROP POLICY IF EXISTS "allow_all_operations" ON hr_employee_master;
DROP POLICY IF EXISTS "allow_select" ON hr_employee_master;
DROP POLICY IF EXISTS "allow_insert" ON hr_employee_master;
DROP POLICY IF EXISTS "allow_update" ON hr_employee_master;
DROP POLICY IF EXISTS "allow_delete" ON hr_employee_master;
DROP POLICY IF EXISTS "anon_select" ON hr_employee_master;
DROP POLICY IF EXISTS "anon_insert" ON hr_employee_master;
DROP POLICY IF EXISTS "anon_update" ON hr_employee_master;
DROP POLICY IF EXISTS "anon_delete" ON hr_employee_master;

-- Simple permissive policy for all operations (matches denomination_user_preferences pattern)
CREATE POLICY "Allow all access to hr_employee_master"
  ON hr_employee_master
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to all roles (matches denomination_user_preferences pattern)
GRANT ALL ON hr_employee_master TO authenticated;
GRANT ALL ON hr_employee_master TO service_role;
GRANT ALL ON hr_employee_master TO anon;
