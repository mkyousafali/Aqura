-- Migration: Add RLS policies for hr_employee_contacts table
-- This resolves the 406 error when accessing hr_employee_contacts

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

-- Also ensure the active_employee_contacts view can be accessed by updating it
-- (Views inherit RLS policies from their underlying tables, but we can add security definer)
CREATE OR REPLACE VIEW active_employee_contacts 
SECURITY DEFINER AS
SELECT 
    ec.id,
    ec.employee_id,
    ec.email,
    ec.whatsapp_number,
    ec.contact_number,
    ec.created_at,
    ec.updated_at
FROM hr_employee_contacts ec
WHERE ec.is_active = true;

-- Update the get_employee_primary_contact function to be security definer
CREATE OR REPLACE FUNCTION get_employee_primary_contact(emp_id UUID)
RETURNS TABLE(
    email VARCHAR,
    whatsapp_number VARCHAR,
    contact_number VARCHAR
) 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ec.email,
        ec.whatsapp_number,
        ec.contact_number
    FROM hr_employee_contacts ec
    WHERE ec.employee_id = emp_id 
      AND ec.is_active = true
    ORDER BY ec.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON hr_employee_contacts TO authenticated;
GRANT SELECT ON active_employee_contacts TO authenticated;
GRANT EXECUTE ON FUNCTION get_employee_primary_contact(UUID) TO authenticated;

-- Add comments for the policies
COMMENT ON POLICY "Authenticated users can view hr employee contacts" ON hr_employee_contacts IS 'Allows authenticated users to view employee contact information';
COMMENT ON POLICY "Authenticated users can insert hr employee contacts" ON hr_employee_contacts IS 'Allows authenticated users to add new employee contact information';
COMMENT ON POLICY "Authenticated users can update hr employee contacts" ON hr_employee_contacts IS 'Allows authenticated users to update employee contact information';
COMMENT ON POLICY "Authenticated users can delete hr employee contacts" ON hr_employee_contacts IS 'Allows authenticated users to delete employee contact information';

RAISE NOTICE 'RLS policies added for hr_employee_contacts table - 406 error should be resolved';