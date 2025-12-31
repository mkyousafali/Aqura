-- Create social_links table to store social media links for branches

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
  
  -- Foreign key constraint
  CONSTRAINT fk_social_links_branch FOREIGN KEY (branch_id)
    REFERENCES branches(id) ON DELETE CASCADE
);

-- Create index on branch_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_social_links_branch_id ON social_links(branch_id);

-- Enable RLS (Row Level Security)
ALTER TABLE social_links ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
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

-- Clean RLS policies - allow all authenticated users to view and modify
CREATE POLICY "Enable read access for all authenticated users" ON social_links
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Enable insert for authenticated users" ON social_links
  FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" ON social_links
  FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Enable delete for authenticated users" ON social_links
  FOR DELETE
  TO authenticated
  USING (true);

-- Service role has full access
CREATE POLICY "service_role_full_access" ON social_links
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_social_links_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS social_links_updated_at_trigger ON social_links;

CREATE TRIGGER social_links_updated_at_trigger
BEFORE UPDATE ON social_links
FOR EACH ROW
EXECUTE FUNCTION update_social_links_updated_at();

-- Create RPC function to upsert social links
CREATE OR REPLACE FUNCTION upsert_social_links(
  p_branch_id BIGINT,
  p_facebook TEXT DEFAULT NULL,
  p_whatsapp TEXT DEFAULT NULL,
  p_instagram TEXT DEFAULT NULL,
  p_tiktok TEXT DEFAULT NULL,
  p_snapchat TEXT DEFAULT NULL,
  p_website TEXT DEFAULT NULL
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
) AS $$
BEGIN
  RETURN QUERY
  INSERT INTO social_links (branch_id, facebook, whatsapp, instagram, tiktok, snapchat, website)
  VALUES (p_branch_id, p_facebook, p_whatsapp, p_instagram, p_tiktok, p_snapchat, p_website)
  ON CONFLICT (branch_id) DO UPDATE SET
    facebook = COALESCE(p_facebook, social_links.facebook),
    whatsapp = COALESCE(p_whatsapp, social_links.whatsapp),
    instagram = COALESCE(p_instagram, social_links.instagram),
    tiktok = COALESCE(p_tiktok, social_links.tiktok),
    snapchat = COALESCE(p_snapchat, social_links.snapchat),
    website = COALESCE(p_website, social_links.website),
    updated_at = NOW()
  RETURNING *;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON social_links TO authenticated;
GRANT EXECUTE ON FUNCTION upsert_social_links(BIGINT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;

