-- Create denomination_transactions table
-- Stores all Paid and Received transactions (Vendor, Expenses, User, Other)
-- with minimal columns and JSON for detailed data

CREATE TABLE IF NOT EXISTS denomination_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id INT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  section VARCHAR(20) NOT NULL CHECK (section IN ('paid', 'received')),
  transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('vendor', 'expenses', 'user', 'other')),
  amount DECIMAL(15, 2) NOT NULL,
  remarks TEXT,
  apply_denomination BOOLEAN DEFAULT false,
  -- Stores denomination breakdown: {d500: 0, d200: 0, d100: 0, ..., coins: 0}
  denomination_details JSONB DEFAULT '{}',
  -- Stores entity data based on transaction_type
  -- Vendor: {id, name, code}
  -- Expenses: {id, name, code}
  -- User: {id, name, email}
  -- Other: {particulars}
  entity_data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_by UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_denomination_transactions_branch_id 
  ON denomination_transactions(branch_id);

CREATE INDEX IF NOT EXISTS idx_denomination_transactions_section 
  ON denomination_transactions(section);

CREATE INDEX IF NOT EXISTS idx_denomination_transactions_type 
  ON denomination_transactions(transaction_type);

CREATE INDEX IF NOT EXISTS idx_denomination_transactions_created_at 
  ON denomination_transactions(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_denomination_transactions_branch_section 
  ON denomination_transactions(branch_id, section);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_denomination_transactions_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER denomination_transactions_timestamp_update
BEFORE UPDATE ON denomination_transactions
FOR EACH ROW
EXECUTE FUNCTION update_denomination_transactions_timestamp();
