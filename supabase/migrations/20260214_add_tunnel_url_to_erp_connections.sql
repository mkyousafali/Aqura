-- Add tunnel_url column to erp_connections
-- This stores the Cloudflare Tunnel URL for each branch's ERP bridge API
-- e.g. https://erp-branch3.urbanaqura.com

ALTER TABLE erp_connections
ADD COLUMN IF NOT EXISTS tunnel_url TEXT;

-- Set tunnel URL for branch 3 (Urban Market 02)
UPDATE erp_connections
SET tunnel_url = 'https://erp-branch3.urbanaqura.com'
WHERE server_ip = '192.168.0.3';

COMMENT ON COLUMN erp_connections.tunnel_url IS 'Cloudflare Tunnel URL for the ERP bridge API on this branch server';
