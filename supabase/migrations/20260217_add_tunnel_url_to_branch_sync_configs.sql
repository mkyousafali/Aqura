-- Add tunnel_url column to branch_sync_config for Cloudflare Tunnel fallback
-- When outside local network, sync will use this URL instead of local_supabase_url

ALTER TABLE branch_sync_config
ADD COLUMN IF NOT EXISTS tunnel_url TEXT;

COMMENT ON COLUMN branch_sync_config.tunnel_url IS 'Cloudflare Tunnel URL for the branch Supabase (used when local URL is unreachable)';

-- Update the upsert RPC to accept tunnel_url
CREATE OR REPLACE FUNCTION upsert_branch_sync_config(
    p_branch_id BIGINT,
    p_local_supabase_url TEXT,
    p_local_supabase_key TEXT,
    p_tunnel_url TEXT DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO branch_sync_config (branch_id, local_supabase_url, local_supabase_key, tunnel_url, is_active)
    VALUES (p_branch_id, p_local_supabase_url, p_local_supabase_key, p_tunnel_url, true)
    ON CONFLICT (branch_id) DO UPDATE SET
        local_supabase_url = EXCLUDED.local_supabase_url,
        local_supabase_key = EXCLUDED.local_supabase_key,
        tunnel_url = COALESCE(EXCLUDED.tunnel_url, branch_sync_config.tunnel_url),
        updated_at = now()
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop and recreate get function (return type changed to include tunnel_url)
DROP FUNCTION IF EXISTS get_branch_sync_configs();

CREATE OR REPLACE FUNCTION get_branch_sync_configs()
RETURNS TABLE (
    id BIGINT,
    branch_id BIGINT,
    branch_name_en TEXT,
    branch_name_ar TEXT,
    local_supabase_url TEXT,
    local_supabase_key TEXT,
    tunnel_url TEXT,
    is_active BOOLEAN,
    last_sync_at TIMESTAMPTZ,
    last_sync_status TEXT,
    last_sync_details JSONB,
    sync_tables TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        bsc.id,
        bsc.branch_id,
        b.name_en::TEXT AS branch_name_en,
        b.name_ar::TEXT AS branch_name_ar,
        bsc.local_supabase_url,
        bsc.local_supabase_key,
        bsc.tunnel_url,
        bsc.is_active,
        bsc.last_sync_at,
        bsc.last_sync_status,
        bsc.last_sync_details,
        bsc.sync_tables
    FROM branch_sync_config bsc
    JOIN branches b ON b.id = bsc.branch_id
    WHERE bsc.is_active = true
    ORDER BY b.name_en;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
