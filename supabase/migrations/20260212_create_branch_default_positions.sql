-- Create branch_default_positions table
-- Stores default user assignments for 6 roles per branch
-- Used by StartReceiving to auto-fill positions (except Shelf Stocker which is manual)

CREATE TABLE IF NOT EXISTS branch_default_positions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  branch_manager_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  purchasing_manager_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  inventory_manager_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  accountant_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  night_supervisor_user_ids UUID[] DEFAULT '{}',
  warehouse_handler_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(branch_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_branch_default_positions_branch_id ON branch_default_positions(branch_id);

-- Auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_branch_default_positions_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER branch_default_positions_timestamp_update
BEFORE UPDATE ON branch_default_positions
FOR EACH ROW
EXECUTE FUNCTION update_branch_default_positions_timestamp();
