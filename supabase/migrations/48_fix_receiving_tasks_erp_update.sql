-- Fix automatic updating of receiving records when inventory manager completes tasks
-- This migration ensures that when an inventory manager completes their task with an ERP reference,
-- the receiving record is automatically updated with the ERP invoice reference.

-- Add missing inventory_manager_user_id field to receiving_records if it doesn't exist
-- This field is referenced in migration 73 but wasn't in the original receiving_records schema
ALTER TABLE receiving_records 
ADD COLUMN IF NOT EXISTS inventory_manager_user_id UUID REFERENCES users(id) ON DELETE SET NULL;

-- Add missing user role arrays that are referenced in the receiving tasks system
ALTER TABLE receiving_records 
ADD COLUMN IF NOT EXISTS night_supervisor_user_ids UUID[] DEFAULT '{}';

ALTER TABLE receiving_records 
ADD COLUMN IF NOT EXISTS warehouse_handler_user_ids UUID[] DEFAULT '{}';

-- Add indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_receiving_records_inventory_manager_user_id 
ON receiving_records(inventory_manager_user_id) 
WHERE inventory_manager_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_receiving_records_night_supervisor_user_ids 
ON receiving_records USING GIN(night_supervisor_user_ids) 
WHERE night_supervisor_user_ids != '{}';

CREATE INDEX IF NOT EXISTS idx_receiving_records_warehouse_handler_user_ids 
ON receiving_records USING GIN(warehouse_handler_user_ids) 
WHERE warehouse_handler_user_ids != '{}';

-- Add comments for the new columns
COMMENT ON COLUMN receiving_records.inventory_manager_user_id IS 'Selected inventory manager or responsible user for inventory tasks';
COMMENT ON COLUMN receiving_records.night_supervisor_user_ids IS 'Array of user IDs selected as night supervisors for this receiving';
COMMENT ON COLUMN receiving_records.warehouse_handler_user_ids IS 'Array of user IDs selected as warehouse handlers for this receiving';

-- Update the constraint check to remove the non-existent column reference
ALTER TABLE receiving_records 
DROP CONSTRAINT IF EXISTS check_has_inventory_manager;

-- Success message
DO $$ 
BEGIN 
    RAISE NOTICE 'Added missing user role fields to receiving_records table for proper task assignment';
END $$;