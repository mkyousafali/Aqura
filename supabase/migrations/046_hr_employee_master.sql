-- Create hr_employee_master table
-- This table links user IDs to their employee IDs across multiple branches
-- Stores references by ID (not names) to maintain integrity when reference data changes

CREATE TABLE IF NOT EXISTS hr_employee_master (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  current_branch_id INT NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
  current_position_id UUID REFERENCES hr_positions(id) ON DELETE SET NULL,
  name_en VARCHAR(255),
  name_ar VARCHAR(255),
  -- JSON mapping of branch_id to employee_id for this user across all branches
  -- Format: {"1": "EMP001", "2": "EMP002", "3": "EMP003"}
  employee_id_mapping JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id)
);

-- Create index on user_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_user_id ON hr_employee_master(user_id);

-- Create index on current_branch_id for filtering
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_branch_id ON hr_employee_master(current_branch_id);

-- Create index on current_position_id for filtering
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_position_id ON hr_employee_master(current_position_id);

-- Create index on employee_id_mapping for JSONB queries (if needed for searching)
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_employee_mapping ON hr_employee_master USING GIN(employee_id_mapping);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_hr_employee_master_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER hr_employee_master_timestamp_update
BEFORE UPDATE ON hr_employee_master
FOR EACH ROW
EXECUTE FUNCTION update_hr_employee_master_timestamp();
