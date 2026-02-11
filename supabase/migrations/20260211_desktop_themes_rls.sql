-- Enable RLS on desktop_themes with permissive policies

ALTER TABLE desktop_themes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to desktop_themes" ON desktop_themes;

CREATE POLICY "Allow all access to desktop_themes"
  ON desktop_themes
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON desktop_themes TO authenticated;
GRANT ALL ON desktop_themes TO service_role;
GRANT ALL ON desktop_themes TO anon;

-- Grant sequence access for SERIAL id
GRANT USAGE, SELECT ON SEQUENCE desktop_themes_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE desktop_themes_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE desktop_themes_id_seq TO anon;
