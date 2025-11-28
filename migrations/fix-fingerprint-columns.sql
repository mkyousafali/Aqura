-- =====================================================
-- Fix hr_fingerprint_transactions Column Names
-- Date: November 28, 2025
-- Purpose: Rename columns to match sync app expectations
-- =====================================================

-- Rename columns to match sync code
ALTER TABLE hr_fingerprint_transactions 
  RENAME COLUMN transaction_date TO date;

ALTER TABLE hr_fingerprint_transactions 
  RENAME COLUMN transaction_time TO time;

ALTER TABLE hr_fingerprint_transactions 
  RENAME COLUMN punch_state TO status;

-- Add missing location column if not exists
ALTER TABLE hr_fingerprint_transactions 
  ADD COLUMN IF NOT EXISTS location TEXT;

-- Verify changes
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'hr_fingerprint_transactions'
ORDER BY ordinal_position;

-- =====================================================
-- Migration Complete
-- Now the sync app can insert data successfully!
-- =====================================================
