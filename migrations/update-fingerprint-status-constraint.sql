-- =====================================================
-- Update hr_fingerprint_transactions Status Constraint
-- Date: November 28, 2025
-- Purpose: Allow all ZKBioTime punch states
-- =====================================================

-- Drop old constraint that only allowed Check In/Check Out
ALTER TABLE hr_fingerprint_transactions 
  DROP CONSTRAINT IF EXISTS chk_hr_fingerprint_punch;

-- Add new constraint with all punch states
ALTER TABLE hr_fingerprint_transactions 
  ADD CONSTRAINT chk_hr_fingerprint_punch 
  CHECK (status IN (
    'Check In',
    'Check Out',
    'Break In',
    'Break Out',
    'Overtime In',
    'Overtime Out'
  ));

-- Verify constraint
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'hr_fingerprint_transactions'::regclass 
  AND conname = 'chk_hr_fingerprint_punch';

-- =====================================================
-- Migration Complete
-- Now all punch states can be inserted!
-- =====================================================
