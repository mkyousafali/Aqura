-- Create bank_reconciliations table
-- Stores individual reconciliation entries from CloseBox bank reconciliation popup
-- Each row = one reconciliation number with Mada/Visa/MC/GPay/Other amounts

CREATE TABLE IF NOT EXISTS bank_reconciliations (
  id SERIAL PRIMARY KEY,
  operation_id UUID NOT NULL REFERENCES box_operations(id) ON DELETE CASCADE,
  branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
  pos_number INTEGER NOT NULL DEFAULT 1,
  supervisor_id UUID REFERENCES users(id) ON DELETE SET NULL,
  cashier_id UUID REFERENCES users(id) ON DELETE SET NULL,
  reconciliation_number VARCHAR(100) NOT NULL DEFAULT '',
  mada_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  visa_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  mastercard_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  google_pay_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  other_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_bank_reconciliations_operation_id ON bank_reconciliations(operation_id);
CREATE INDEX IF NOT EXISTS idx_bank_reconciliations_branch_id ON bank_reconciliations(branch_id);
CREATE INDEX IF NOT EXISTS idx_bank_reconciliations_created_at ON bank_reconciliations(created_at);

-- Auto-update trigger
CREATE OR REPLACE FUNCTION update_bank_reconciliations_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER bank_reconciliations_timestamp_update
BEFORE UPDATE ON bank_reconciliations
FOR EACH ROW
EXECUTE FUNCTION update_bank_reconciliations_timestamp();

-- Enable RLS
ALTER TABLE bank_reconciliations ENABLE ROW LEVEL SECURITY;

-- Permissive policy (matching app pattern)
CREATE POLICY "Allow all access to bank_reconciliations"
  ON bank_reconciliations
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to all roles
GRANT ALL ON bank_reconciliations TO authenticated;
GRANT ALL ON bank_reconciliations TO service_role;
GRANT ALL ON bank_reconciliations TO anon;

-- Grant sequence access
GRANT USAGE, SELECT ON SEQUENCE bank_reconciliations_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE bank_reconciliations_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE bank_reconciliations_id_seq TO anon;
