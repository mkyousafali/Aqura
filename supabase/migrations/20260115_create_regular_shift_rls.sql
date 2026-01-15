-- Enable RLS on regular_shift table with permissive policies

-- Enable RLS (Row Level Security)
ALTER TABLE regular_shift ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to regular_shift" ON regular_shift;

-- Simple permissive policy for all operations
-- This matches the pattern used in denomination_user_preferences and hr_employee_master
CREATE POLICY "Allow all access to regular_shift"
  ON regular_shift
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON regular_shift TO authenticated;
GRANT ALL ON regular_shift TO service_role;
GRANT ALL ON regular_shift TO anon;
