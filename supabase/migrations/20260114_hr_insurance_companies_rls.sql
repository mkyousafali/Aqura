-- Enable RLS on hr_insurance_companies with permissive policies

-- Enable RLS (Row Level Security)
ALTER TABLE hr_insurance_companies ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to hr_insurance_companies" ON hr_insurance_companies;

-- Simple permissive policy for all operations
-- This matches the pattern used in denomination_user_preferences and hr_employee_master
CREATE POLICY "Allow all access to hr_insurance_companies"
  ON hr_insurance_companies
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON hr_insurance_companies TO authenticated;
GRANT ALL ON hr_insurance_companies TO service_role;
GRANT ALL ON hr_insurance_companies TO anon;
