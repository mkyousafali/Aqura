-- Complete setup for social_links table - ensure full API exposure

-- Step 1: Ensure table exists and has correct structure
CREATE TABLE IF NOT EXISTS social_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id BIGINT NOT NULL UNIQUE,
  facebook TEXT,
  whatsapp TEXT,
  instagram TEXT,
  tiktok TEXT,
  snapchat TEXT,
  website TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  CONSTRAINT fk_social_links_branch FOREIGN KEY (branch_id)
    REFERENCES branches(id) ON DELETE CASCADE
);

-- Step 2: Ensure index exists
CREATE INDEX IF NOT EXISTS idx_social_links_branch_id ON social_links(branch_id);

-- Step 3: Ensure table is in public schema (required for API)
ALTER TABLE social_links SET SCHEMA public;

-- Step 4: Enable RLS
ALTER TABLE social_links ENABLE ROW LEVEL SECURITY;

-- Step 5: Drop all old policies
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
DROP POLICY IF EXISTS "Allow anon insert social_links" ON social_links;
DROP POLICY IF EXISTS "Allow authenticated users to create social_links" ON social_links;
DROP POLICY IF EXISTS "Allow authenticated users to read social_links" ON social_links;
DROP POLICY IF EXISTS "Allow authenticated users to update social_links" ON social_links;
DROP POLICY IF EXISTS "allow_all_operations_social_links" ON social_links;
DROP POLICY IF EXISTS "allow_delete_social_links" ON social_links;
DROP POLICY IF EXISTS "allow_insert_social_links" ON social_links;
DROP POLICY IF EXISTS "allow_select_social_links" ON social_links;
DROP POLICY IF EXISTS "allow_update_social_links" ON social_links;
DROP POLICY IF EXISTS "anon_full_access_social_links" ON social_links;
DROP POLICY IF EXISTS "authenticated_full_access_social_links" ON social_links;
DROP POLICY IF EXISTS "Enable all access for social_links" ON social_links;

-- Step 6: Create single permissive policy (like view_offer)
CREATE POLICY "Enable all access for social_links" ON social_links
  FOR ALL
  TO public
  USING (true)
  WITH CHECK (true);

-- Step 7: Grant schema usage to all roles
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

-- Step 8: Grant full table permissions to all roles
GRANT ALL PRIVILEGES ON public.social_links TO anon, authenticated, service_role;

-- Step 9: Grant sequence permissions (for any generated IDs)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- Step 10: Ensure function is accessible
DROP FUNCTION IF EXISTS upsert_social_links(BIGINT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;

CREATE FUNCTION upsert_social_links(
  _branch_id BIGINT,
  _facebook TEXT DEFAULT NULL,
  _whatsapp TEXT DEFAULT NULL,
  _instagram TEXT DEFAULT NULL,
  _tiktok TEXT DEFAULT NULL,
  _snapchat TEXT DEFAULT NULL,
  _website TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  branch_id BIGINT,
  facebook TEXT,
  whatsapp TEXT,
  instagram TEXT,
  tiktok TEXT,
  snapchat TEXT,
  website TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
) LANGUAGE sql AS $$
  INSERT INTO public.social_links (branch_id, facebook, whatsapp, instagram, tiktok, snapchat, website)
  VALUES (_branch_id, _facebook, _whatsapp, _instagram, _tiktok, _snapchat, _website)
  ON CONFLICT (branch_id) DO UPDATE SET
    facebook = _facebook,
    whatsapp = _whatsapp,
    instagram = _instagram,
    tiktok = _tiktok,
    snapchat = _snapchat,
    website = _website,
    updated_at = NOW()
  RETURNING id, branch_id, facebook, whatsapp, instagram, tiktok, snapchat, website, created_at, updated_at
$$;

GRANT EXECUTE ON FUNCTION upsert_social_links(_branch_id BIGINT, _facebook TEXT, _whatsapp TEXT, _instagram TEXT, _tiktok TEXT, _snapchat TEXT, _website TEXT) TO anon, authenticated, service_role;
