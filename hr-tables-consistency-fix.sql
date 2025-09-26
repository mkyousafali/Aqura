-- =====================================================
-- FIX BOTH HR TABLES - CONSISTENT EMPLOYEE ID FORMAT
-- Run this in Supabase to make both tables use same employee_id and name format
-- =====================================================

-- =====================================================
-- FIX HR EMPLOYEES TABLE
-- =====================================================

-- Step 1: Update employees table structure
ALTER TABLE hr_employees 
    ALTER COLUMN employee_id TYPE VARCHAR(10), -- Numeric IDs: 1, 25, 120, 1251
    ALTER COLUMN name TYPE VARCHAR(200); -- Consistent name field

-- Step 2: Update table comment
COMMENT ON TABLE hr_employees IS 'HR Employees - Upload Employees function with numeric employee_id and name fields';

-- =====================================================
-- FIX HR FINGERPRINT TRANSACTIONS TABLE
-- =====================================================

-- Step 3: Drop and recreate fingerprint table with consistent structure
DROP TABLE IF EXISTS hr_fingerprint_transactions CASCADE;

CREATE TABLE hr_fingerprint_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id VARCHAR(10) NOT NULL, -- Numeric employee ID (1, 25, 120, 1251) - MATCHES hr_employees
    name VARCHAR(200), -- Employee name field - MATCHES hr_employees
    branch_id UUID NOT NULL, -- References branches.id (selected in frontend)
    transaction_date DATE NOT NULL, -- Separate date field (yyyy-mm-dd)
    transaction_time TIME NOT NULL, -- Separate time field (hh:mm AM/PM)
    punch_state VARCHAR(20) NOT NULL, -- 'Check In', 'Check Out'
    device_id VARCHAR(50), -- Optional device info
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT chk_hr_fingerprint_punch CHECK (punch_state IN ('Check In', 'Check Out'))
);

-- Step 4: Add indexes for performance
CREATE INDEX idx_hr_fingerprint_employee_id ON hr_fingerprint_transactions(employee_id);
CREATE INDEX idx_hr_fingerprint_branch_id ON hr_fingerprint_transactions(branch_id);
CREATE INDEX idx_hr_fingerprint_date ON hr_fingerprint_transactions(transaction_date);
CREATE INDEX idx_hr_fingerprint_punch_state ON hr_fingerprint_transactions(punch_state);

-- Step 5: Update table comment
COMMENT ON TABLE hr_fingerprint_transactions IS 'HR Fingerprint Transactions - Excel upload with numeric employee_id and name matching hr_employees table';

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check hr_employees structure
SELECT 'hr_employees' as table_name, column_name, data_type, character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'hr_employees' 
AND table_schema = 'public'
AND column_name IN ('employee_id', 'name')
ORDER BY ordinal_position;

-- Check hr_fingerprint_transactions structure  
SELECT 'hr_fingerprint_transactions' as table_name, column_name, data_type, character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'hr_fingerprint_transactions' 
AND table_schema = 'public'
AND column_name IN ('employee_id', 'name')
ORDER BY ordinal_position;

-- =====================================================
-- UPDATED EXCEL TEMPLATES FORMAT
-- =====================================================

-- UPLOAD EMPLOYEES TEMPLATE:
-- Employee ID | Name              
-- 1          | Ahmed Mohammed    
-- 25         | Sarah Ali         
-- 120        | Omar Hassan       
-- 1251       | Fatima Ahmed      

-- UPLOAD FINGERPRINT TEMPLATE:
-- Employee ID | Name              | Date       | Time     | Punch State
-- 1          | Ahmed Mohammed    | 2024-09-25 | 08:00 AM | Check In
-- 1          | Ahmed Mohammed    | 2024-09-25 | 05:30 PM | Check Out
-- 25         | Sarah Ali         | 2024-09-25 | 09:15 AM | Check In
-- 120        | Omar Hassan       | 2024-09-25 | 08:45 AM | Check In

-- NOTES:
-- - Upload Employees: Only Employee ID and Name (Branch selected in UI, Hire Date updated later)
-- - Upload Fingerprint: Employee ID, Name, Date, Time, Punch State
-- - Both use consistent numeric Employee ID format (1, 25, 120, 1251)
-- - Easy data linking between functions