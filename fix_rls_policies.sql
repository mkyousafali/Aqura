-- Combined RLS Fix Script
-- This script fixes both hr_employee_contacts and employee_warnings RLS issues

-- ========================================================
-- FIX 1: HR Employee Contacts RLS (fixes 406 error)
-- ========================================================

-- Enable RLS on hr_employee_contacts table
ALTER TABLE public.hr_employee_contacts ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies first (in case they exist)
DROP POLICY IF EXISTS "Authenticated users can view hr employee contacts" ON hr_employee_contacts;
DROP POLICY IF EXISTS "Authenticated users can insert hr employee contacts" ON hr_employee_contacts;  
DROP POLICY IF EXISTS "Authenticated users can update hr employee contacts" ON hr_employee_contacts;
DROP POLICY IF EXISTS "Authenticated users can delete hr employee contacts" ON hr_employee_contacts;

-- Create comprehensive RLS policies for hr_employee_contacts
-- Policy for viewing contacts (authenticated users can view all contacts)
CREATE POLICY "Authenticated users can view hr employee contacts" 
ON hr_employee_contacts FOR SELECT 
USING (auth.role() = 'authenticated');

-- Policy for inserting contacts (authenticated users can insert)
CREATE POLICY "Authenticated users can insert hr employee contacts" 
ON hr_employee_contacts FOR INSERT 
WITH CHECK (auth.role() = 'authenticated');

-- Policy for updating contacts (authenticated users can update)  
CREATE POLICY "Authenticated users can update hr employee contacts" 
ON hr_employee_contacts FOR UPDATE 
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- Policy for deleting contacts (authenticated users can delete)
CREATE POLICY "Authenticated users can delete hr employee contacts" 
ON hr_employee_contacts FOR DELETE 
USING (auth.role() = 'authenticated');

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON hr_employee_contacts TO authenticated;

-- ========================================================
-- FIX 2: Employee Warnings RLS (fixes notification creation)
-- ========================================================

-- The employee_warnings table already exists, just need to add RLS policies

-- Enable RLS on employee_warnings table
ALTER TABLE public.employee_warnings ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies first (in case they exist)
DROP POLICY IF EXISTS "Authenticated users can view employee warnings" ON employee_warnings;
DROP POLICY IF EXISTS "Authenticated users can insert employee warnings" ON employee_warnings;
DROP POLICY IF EXISTS "Authenticated users can update employee warnings" ON employee_warnings;
DROP POLICY IF EXISTS "Authenticated users can delete employee warnings" ON employee_warnings;

-- Create comprehensive RLS policies for employee_warnings
-- Policy for viewing warnings (authenticated users can view all warnings)
CREATE POLICY "Authenticated users can view employee warnings" 
ON employee_warnings FOR SELECT 
USING (auth.role() = 'authenticated');

-- Policy for inserting warnings (authenticated users can insert)
CREATE POLICY "Authenticated users can insert employee warnings" 
ON employee_warnings FOR INSERT 
WITH CHECK (auth.role() = 'authenticated');

-- Policy for updating warnings (authenticated users can update)  
CREATE POLICY "Authenticated users can update employee warnings" 
ON employee_warnings FOR UPDATE 
USING (auth.role() = 'authenticated')
WITH CHECK (auth.role() = 'authenticated');

-- Policy for deleting warnings (authenticated users can delete)
CREATE POLICY "Authenticated users can delete employee warnings" 
ON employee_warnings FOR DELETE 
USING (auth.role() = 'authenticated');

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON employee_warnings TO authenticated;

-- ========================================================
-- VERIFICATION QUERIES
-- ========================================================

-- Verify RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('hr_employee_contacts', 'employee_warnings');

-- Verify policies exist
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('hr_employee_contacts', 'employee_warnings');

-- Success message
DO $$ 
BEGIN
    RAISE NOTICE 'RLS policies applied successfully for both hr_employee_contacts and employee_warnings tables';
END $$;