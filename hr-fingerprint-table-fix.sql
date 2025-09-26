-- =====================================================
-- FIX HR FINGERPRINT TRANSACTIONS - MATCH EXCEL UPLOAD
-- Run this in Supabase to fix the fingerprint table structure
-- =====================================================

-- Step 1: Drop the current table and recreate with correct structure for Excel import
DROP TABLE IF EXISTS hr_fingerprint_transactions CASCADE;

-- Step 2: Create new table matching Excel template format
CREATE TABLE hr_fingerprint_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id VARCHAR(50) NOT NULL, -- Employee ID from Excel (e.g., EMP001)
    employee_name VARCHAR(200), -- Employee name from Excel (for validation)
    branch_id UUID NOT NULL, -- References branches.id (selected in frontend)
    transaction_date DATE NOT NULL, -- Separate date field (yyyy-mm-dd)
    transaction_time TIME NOT NULL, -- Separate time field (hh:mm AM/PM)
    punch_state VARCHAR(20) NOT NULL, -- 'Check In', 'Check Out'
    device_id VARCHAR(50), -- Optional device info
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_hr_fingerprint_punch CHECK (punch_state IN ('Check In', 'Check Out'))
);

-- Step 3: Add indexes for performance
CREATE INDEX idx_hr_fingerprint_employee_id ON hr_fingerprint_transactions(employee_id);
CREATE INDEX idx_hr_fingerprint_branch_id ON hr_fingerprint_transactions(branch_id);
CREATE INDEX idx_hr_fingerprint_date ON hr_fingerprint_transactions(transaction_date);
CREATE INDEX idx_hr_fingerprint_punch_state ON hr_fingerprint_transactions(punch_state);

-- Step 4: Update table comment
COMMENT ON TABLE hr_fingerprint_transactions IS 'HR Fingerprint Transactions - Excel upload format with Employee ID, Name, separate Date/Time fields, and Check In/Check Out states';

-- Verification query to check the table structure
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'hr_fingerprint_transactions' 
AND table_schema = 'public'
ORDER BY ordinal_position;