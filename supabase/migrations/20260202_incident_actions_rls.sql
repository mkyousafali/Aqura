-- Enable RLS on incident_actions with permissive policies (matching app pattern)

-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON incident_actions;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON incident_actions;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON incident_actions;
DROP POLICY IF EXISTS "Allow all access to incident_actions" ON incident_actions;

-- Enable RLS (Row Level Security)
ALTER TABLE incident_actions ENABLE ROW LEVEL SECURITY;

-- Simple permissive policy for all operations
-- This matches the pattern used in denomination_user_preferences and hr_employee_master
CREATE POLICY "Allow all access to incident_actions"
  ON incident_actions
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON incident_actions TO authenticated;
GRANT ALL ON incident_actions TO service_role;
GRANT ALL ON incident_actions TO anon;

-- Grant sequence access for auto-generated IDs
GRANT USAGE, SELECT ON SEQUENCE incident_actions_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE incident_actions_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE incident_actions_id_seq TO anon;
