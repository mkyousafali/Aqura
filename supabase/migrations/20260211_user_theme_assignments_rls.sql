-- Enable RLS on user_theme_assignments with permissive policies

ALTER TABLE user_theme_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to user_theme_assignments" ON user_theme_assignments;

CREATE POLICY "Allow all access to user_theme_assignments"
  ON user_theme_assignments
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON user_theme_assignments TO authenticated;
GRANT ALL ON user_theme_assignments TO service_role;
GRANT ALL ON user_theme_assignments TO anon;

-- Grant sequence access for SERIAL id
GRANT USAGE, SELECT ON SEQUENCE user_theme_assignments_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE user_theme_assignments_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE user_theme_assignments_id_seq TO anon;
