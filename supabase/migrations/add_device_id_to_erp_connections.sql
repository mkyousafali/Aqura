-- Add device_id column to erp_connections table
ALTER TABLE erp_connections ADD COLUMN IF NOT EXISTS device_id TEXT;

-- Create index on device_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_erp_connections_device_id ON erp_connections(device_id);

-- Update existing record with a placeholder device_id
UPDATE erp_connections 
SET device_id = 'legacy-device-' || id::text 
WHERE device_id IS NULL;
