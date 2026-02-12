-- Enable RLS on receiving_user_defaults with permissive policies

-- Enable RLS
ALTER TABLE receiving_user_defaults ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow all access to receiving_user_defaults" ON receiving_user_defaults;

-- Simple permissive policy for all operations
CREATE POLICY "Allow all access to receiving_user_defaults"
  ON receiving_user_defaults
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - anon, authenticated, service_role)
GRANT ALL ON receiving_user_defaults TO anon;
GRANT ALL ON receiving_user_defaults TO authenticated;
GRANT ALL ON receiving_user_defaults TO service_role;
