-- Update RLS policies for social_links table to match view_offer pattern

-- Drop existing policies
DROP POLICY IF EXISTS "authenticated_can_view_social_links" ON social_links;
DROP POLICY IF EXISTS "authenticated_can_insert_social_links" ON social_links;
DROP POLICY IF EXISTS "authenticated_can_update_social_links" ON social_links;
DROP POLICY IF EXISTS "authenticated_can_delete_social_links" ON social_links;
DROP POLICY IF EXISTS "Service role has full access to social_links" ON social_links;
DROP POLICY IF EXISTS "Allow anon insert social_links" ON social_links;
DROP POLICY IF EXISTS "anon_full_access_social_links" ON social_links;
DROP POLICY IF EXISTS "authenticated_full_access_social_links" ON social_links;
DROP POLICY IF EXISTS "allow_all_operations_social_links" ON social_links;
DROP POLICY IF EXISTS "allow_select_social_links" ON social_links;
DROP POLICY IF EXISTS "allow_insert_social_links" ON social_links;
DROP POLICY IF EXISTS "allow_update_social_links" ON social_links;
DROP POLICY IF EXISTS "allow_delete_social_links" ON social_links;
DROP POLICY IF EXISTS "Enable read access for all authenticated users" ON social_links;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON social_links;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON social_links;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON social_links;
DROP POLICY IF EXISTS "service_role_full_access" ON social_links;

-- Enable RLS if not already enabled
ALTER TABLE social_links ENABLE ROW LEVEL SECURITY;

-- Apply same policies as view_offer table
CREATE POLICY "Allow anon insert social_links" ON social_links
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to create social_links" ON social_links
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Allow authenticated users to read social_links" ON social_links
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "Allow authenticated users to update social_links" ON social_links
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role has full access to social_links" ON social_links
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "allow_all_operations_social_links" ON social_links
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "allow_delete_social_links" ON social_links
  FOR DELETE
  TO public
  USING (true);

CREATE POLICY "allow_insert_social_links" ON social_links
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "allow_select_social_links" ON social_links
  FOR SELECT
  TO public
  USING (true);

CREATE POLICY "allow_update_social_links" ON social_links
  FOR UPDATE
  TO public
  USING (true)
  WITH CHECK (true);

CREATE POLICY "anon_full_access_social_links" ON social_links
  FOR ALL
  TO public
  USING ((jwt() ->> 'role'::text) = 'anon'::text);

CREATE POLICY "authenticated_full_access_social_links" ON social_links
  FOR ALL
  TO public
  USING (uid() IS NOT NULL);

CREATE POLICY "Enable all access for social_links" ON social_links
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);
