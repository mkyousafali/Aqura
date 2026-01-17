-- Create processed_fingerprint_transactions table
CREATE TABLE processed_fingerprint_transactions (
    id TEXT PRIMARY KEY,
    center_id TEXT NOT NULL,
    employee_id TEXT NOT NULL,
    branch_id TEXT NOT NULL,
    punch_date DATE NOT NULL,
    punch_time TIME NOT NULL,
    status TEXT,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (center_id) REFERENCES hr_employee_master(id) ON DELETE CASCADE
);

-- Create index for better query performance
CREATE INDEX idx_processed_fingerprint_center_id ON processed_fingerprint_transactions(center_id);
CREATE INDEX idx_processed_fingerprint_employee_id ON processed_fingerprint_transactions(employee_id);
CREATE INDEX idx_processed_fingerprint_branch_id ON processed_fingerprint_transactions(branch_id);
CREATE INDEX idx_processed_fingerprint_punch_date ON processed_fingerprint_transactions(punch_date);

-- Enable RLS for processed_fingerprint_transactions
ALTER TABLE processed_fingerprint_transactions ENABLE ROW LEVEL SECURITY;

-- Simple permissive policy matching the working pattern from TABLE_CREATION_RLS_GUIDE
CREATE POLICY "Allow all access to processed_fingerprint_transactions"
  ON processed_fingerprint_transactions
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to all roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON processed_fingerprint_transactions TO anon;
GRANT ALL ON processed_fingerprint_transactions TO authenticated;
GRANT ALL ON processed_fingerprint_transactions TO service_role;

-- Sequence for generating PF1, PF2, PF3... primary keys
CREATE SEQUENCE processed_fingerprint_transactions_seq START WITH 1;
