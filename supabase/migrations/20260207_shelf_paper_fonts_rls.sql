-- Enable RLS on shelf_paper_fonts with permissive policies (matching app pattern)

-- Enable RLS (Row Level Security)
ALTER TABLE shelf_paper_fonts ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to shelf_paper_fonts" ON shelf_paper_fonts;

-- Simple permissive policy for all operations
CREATE POLICY "Allow all access to shelf_paper_fonts"
  ON shelf_paper_fonts
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON shelf_paper_fonts TO authenticated;
GRANT ALL ON shelf_paper_fonts TO service_role;
GRANT ALL ON shelf_paper_fonts TO anon;
