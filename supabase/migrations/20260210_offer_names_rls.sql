-- Enable RLS on offer_names with permissive policies (matching app pattern)

-- Enable RLS (Row Level Security)
ALTER TABLE offer_names ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to offer_names" ON offer_names;

-- Simple permissive policy for all operations
CREATE POLICY "Allow all access to offer_names"
  ON offer_names
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON offer_names TO authenticated;
GRANT ALL ON offer_names TO service_role;
GRANT ALL ON offer_names TO anon;
