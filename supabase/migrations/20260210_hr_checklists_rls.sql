-- Enable RLS on hr_checklists with permissive policies

-- Enable Row Level Security
ALTER TABLE hr_checklists ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Allow all access to hr_checklists" ON hr_checklists;

-- Simple permissive policy for all operations
CREATE POLICY "Allow all access to hr_checklists"
  ON hr_checklists
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (anon required since app uses anon key)
GRANT ALL ON hr_checklists TO anon;
GRANT ALL ON hr_checklists TO authenticated;
GRANT ALL ON hr_checklists TO service_role;

-- Grant sequence usage so inserts can auto-generate IDs
GRANT USAGE, SELECT ON SEQUENCE hr_checklists_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE hr_checklists_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE hr_checklists_id_seq TO service_role;
