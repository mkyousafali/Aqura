-- Add location_link column to social_links table

ALTER TABLE public.social_links
ADD COLUMN location_link TEXT;

-- Update RPC function to include location_link parameter
DROP FUNCTION IF EXISTS upsert_social_links(BIGINT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;

CREATE FUNCTION upsert_social_links(
  _branch_id BIGINT,
  _facebook TEXT DEFAULT NULL,
  _whatsapp TEXT DEFAULT NULL,
  _instagram TEXT DEFAULT NULL,
  _tiktok TEXT DEFAULT NULL,
  _snapchat TEXT DEFAULT NULL,
  _website TEXT DEFAULT NULL,
  _location_link TEXT DEFAULT NULL
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
  location_link TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE
) LANGUAGE sql AS $$
  INSERT INTO public.social_links (branch_id, facebook, whatsapp, instagram, tiktok, snapchat, website, location_link)
  VALUES (_branch_id, _facebook, _whatsapp, _instagram, _tiktok, _snapchat, _website, _location_link)
  ON CONFLICT (branch_id) DO UPDATE SET
    facebook = _facebook,
    whatsapp = _whatsapp,
    instagram = _instagram,
    tiktok = _tiktok,
    snapchat = _snapchat,
    website = _website,
    location_link = _location_link,
    updated_at = NOW()
  RETURNING id, branch_id, facebook, whatsapp, instagram, tiktok, snapchat, website, location_link, created_at, updated_at
$$;

GRANT EXECUTE ON FUNCTION upsert_social_links(_branch_id BIGINT, _facebook TEXT, _whatsapp TEXT, _instagram TEXT, _tiktok TEXT, _snapchat TEXT, _website TEXT, _location_link TEXT) TO anon, authenticated, service_role;
