-- Enable RLS on branch_default_positions with permissive policies

-- Enable RLS (Row Level Security)
ALTER TABLE branch_default_positions ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to branch_default_positions" ON branch_default_positions;

-- Simple permissive policy for all operations
CREATE POLICY "Allow all access to branch_default_positions"
  ON branch_default_positions
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON branch_default_positions TO authenticated;
GRANT ALL ON branch_default_positions TO service_role;
GRANT ALL ON branch_default_positions TO anon;
