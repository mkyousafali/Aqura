-- Enable RLS on nationalities with permissive policies

-- Enable RLS (Row Level Security)
ALTER TABLE nationalities ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to nationalities" ON nationalities;

-- Simple permissive policy for all operations
CREATE POLICY "Allow all access to nationalities"
  ON nationalities
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles
GRANT ALL ON nationalities TO authenticated;
GRANT ALL ON nationalities TO service_role;
GRANT ALL ON nationalities TO anon;
