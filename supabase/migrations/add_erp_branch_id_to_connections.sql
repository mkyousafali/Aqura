-- Add erp_branch_id column to erp_connections table
-- This stores the branch ID from the ERP system (1, 2, 3, 4, 5, etc.)

ALTER TABLE erp_connections 
ADD COLUMN IF NOT EXISTS erp_branch_id INTEGER;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_erp_connections_erp_branch_id 
ON erp_connections(erp_branch_id);

-- Update existing records to set erp_branch_id if needed
-- This assumes device_id might contain branch info or needs manual update
COMMENT ON COLUMN erp_connections.erp_branch_id IS 'Branch ID from ERP system (1, 2, 3, etc.)';

-- Verify the change
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'erp_connections'
ORDER BY ordinal_position;
