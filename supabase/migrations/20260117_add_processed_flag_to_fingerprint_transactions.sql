-- Add processed flag to hr_fingerprint_transactions
ALTER TABLE hr_fingerprint_transactions ADD COLUMN IF NOT EXISTS processed BOOLEAN DEFAULT FALSE;

-- Create index for better query performance on processed flag
CREATE INDEX IF NOT EXISTS idx_fingerprint_transactions_processed ON hr_fingerprint_transactions(processed);
