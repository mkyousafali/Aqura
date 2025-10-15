-- =============================================
-- Add Inventory Manager, Night Supervisors, and Warehouse Handlers to Receiving Records
-- =============================================

-- Add new user role fields to receiving_records table
ALTER TABLE receiving_records ADD COLUMN inventory_manager_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE receiving_records ADD COLUMN night_supervisor_user_ids INTEGER[] DEFAULT '{}';
ALTER TABLE receiving_records ADD COLUMN warehouse_handler_user_ids INTEGER[] DEFAULT '{}';

-- Add indexes for the new fields for performance
CREATE INDEX idx_receiving_records_inventory_manager_user_id ON receiving_records(inventory_manager_user_id);
CREATE INDEX idx_receiving_records_night_supervisor_user_ids ON receiving_records USING GIN(night_supervisor_user_ids);
CREATE INDEX idx_receiving_records_warehouse_handler_user_ids ON receiving_records USING GIN(warehouse_handler_user_ids);

-- Add comments for documentation
COMMENT ON COLUMN receiving_records.inventory_manager_user_id IS 'Single user responsible for inventory management for this receiving';
COMMENT ON COLUMN receiving_records.night_supervisor_user_ids IS 'Array of user IDs for night supervisors assigned to this receiving';
COMMENT ON COLUMN receiving_records.warehouse_handler_user_ids IS 'Array of user IDs for warehouse and stock handlers assigned to this receiving';