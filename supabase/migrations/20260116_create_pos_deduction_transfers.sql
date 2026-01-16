-- Create POS Deduction Transfers table
-- This table stores records when a cashier has a shortage more than 5
-- The primary key is the employee id from hr_employee_master

-- Create ENUM type for deduction status
DO $$ BEGIN
    CREATE TYPE pos_deduction_status AS ENUM ('Proposed', 'Deducted', 'Forgiven', 'Cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS pos_deduction_transfers (
    id TEXT NOT NULL REFERENCES hr_employee_master(id) ON DELETE CASCADE,
    box_number INTEGER NOT NULL,
    branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    cashier_user_id TEXT NOT NULL REFERENCES hr_employee_master(id) ON DELETE CASCADE,
    closed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    completed_by_name VARCHAR(255),
    short_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    status pos_deduction_status NOT NULL DEFAULT 'Proposed',
    date_created_box TIMESTAMPTZ NOT NULL,
    date_closed_box TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Composite primary key: employee id + box_number + date_closed_box
    PRIMARY KEY (id, box_number, date_closed_box)
);

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_pos_deduction_transfers_cashier ON pos_deduction_transfers(cashier_user_id);
CREATE INDEX IF NOT EXISTS idx_pos_deduction_transfers_branch ON pos_deduction_transfers(branch_id);
CREATE INDEX IF NOT EXISTS idx_pos_deduction_transfers_date_closed ON pos_deduction_transfers(date_closed_box);

-- Enable RLS with permissive policy (matching app pattern)
ALTER TABLE pos_deduction_transfers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to pos_deduction_transfers" ON pos_deduction_transfers;

-- Simple permissive policy for all operations
-- This matches the pattern used in denomination_user_preferences and hr_employee_master
CREATE POLICY "Allow all access to pos_deduction_transfers"
  ON pos_deduction_transfers
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON pos_deduction_transfers TO authenticated;
GRANT ALL ON pos_deduction_transfers TO service_role;
GRANT ALL ON pos_deduction_transfers TO anon;

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_pos_deduction_transfers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_pos_deduction_transfers_updated_at ON pos_deduction_transfers;

CREATE TRIGGER trigger_update_pos_deduction_transfers_updated_at
BEFORE UPDATE ON pos_deduction_transfers
FOR EACH ROW
EXECUTE FUNCTION update_pos_deduction_transfers_updated_at();

-- Add comment to table
COMMENT ON TABLE pos_deduction_transfers IS 'Stores POS deduction transfer records when cashier has shortage more than 5';
