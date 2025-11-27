-- ===================================================================
-- RUN THIS IN SUPABASE SQL EDITOR
-- ===================================================================
-- This adds the erp_branch_id column to store the ERP system's branch ID
-- (which is different from the Supabase branch_id)

-- Add the column
ALTER TABLE erp_connections 
ADD COLUMN IF NOT EXISTS erp_branch_id INTEGER;

-- Add comment
COMMENT ON COLUMN erp_connections.erp_branch_id IS 'Branch ID from ERP system (1, 2, 3, etc.)';

-- Create index
CREATE INDEX IF NOT EXISTS idx_erp_connections_erp_branch_id 
ON erp_connections(erp_branch_id);

-- Verify
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'erp_connections'
ORDER BY ordinal_position;
