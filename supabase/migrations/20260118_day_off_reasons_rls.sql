-- Enable RLS on day_off_reasons with permissive policies (matching app pattern)

-- Enable RLS (Row Level Security)
ALTER TABLE day_off_reasons ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to day_off_reasons" ON day_off_reasons;

-- Simple permissive policy for all operations
-- This matches the pattern used in denomination_user_preferences and hr_employee_master
CREATE POLICY "Allow all access to day_off_reasons"
  ON day_off_reasons
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON day_off_reasons TO authenticated;
GRANT ALL ON day_off_reasons TO service_role;
GRANT ALL ON day_off_reasons TO anon;
