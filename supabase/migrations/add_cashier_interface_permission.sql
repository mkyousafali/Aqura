-- Add cashier_enabled column to interface_permissions table
DO $$ 
BEGIN
    -- Add column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'interface_permissions' 
        AND column_name = 'cashier_enabled'
    ) THEN
        ALTER TABLE interface_permissions 
        ADD COLUMN cashier_enabled BOOLEAN DEFAULT true;
        
        -- Add comment to explain the column
        COMMENT ON COLUMN interface_permissions.cashier_enabled IS 'Controls access to the cashier/POS application';
        
        RAISE NOTICE 'Column cashier_enabled added with default true';
    ELSE
        RAISE NOTICE 'Column cashier_enabled already exists, skipping';
    END IF;
END $$;

-- Set cashier_enabled to true for all existing users (if column was just added or exists)
UPDATE interface_permissions 
SET cashier_enabled = true 
WHERE cashier_enabled IS NULL OR cashier_enabled = false;

-- Create index for better query performance (will skip if exists)
CREATE INDEX IF NOT EXISTS idx_interface_permissions_cashier 
ON interface_permissions(cashier_enabled) 
WHERE cashier_enabled = true;
