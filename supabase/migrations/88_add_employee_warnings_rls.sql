-- Migration: Add RLS policies for employee_warnings table
-- This resolves the 406 error when creating warning notifications

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

-- Add comments for the policies
COMMENT ON POLICY "Authenticated users can view employee warnings" ON employee_warnings IS 'Allows authenticated users to view employee warning records';
COMMENT ON POLICY "Authenticated users can insert employee warnings" ON employee_warnings IS 'Allows authenticated users to create new employee warning records';
COMMENT ON POLICY "Authenticated users can update employee warnings" ON employee_warnings IS 'Allows authenticated users to update employee warning records';
COMMENT ON POLICY "Authenticated users can delete employee warnings" ON employee_warnings IS 'Allows authenticated users to delete employee warning records';

RAISE NOTICE 'RLS policies added for employee_warnings table - warning creation should now work';