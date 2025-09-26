-- =====================================================
-- FIX HR EMPLOYEES TABLE - CLEAN MINIMAL STRUCTURE
-- Run this in Supabase to fix the employee table structure
-- =====================================================

-- Step 1: Drop unnecessary columns - positions/departments managed via hr_position_assignments
ALTER TABLE hr_employees 
    DROP COLUMN IF EXISTS name_en,
    DROP COLUMN IF EXISTS name_ar,
    DROP COLUMN IF EXISTS email,
    DROP COLUMN IF EXISTS phone,
    DROP COLUMN IF EXISTS position,
    DROP COLUMN IF EXISTS department;

-- Step 2: Add name column only if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'hr_employees' 
        AND column_name = 'name'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE hr_employees ADD COLUMN name VARCHAR(200) NOT NULL DEFAULT 'Unknown';
        ALTER TABLE hr_employees ALTER COLUMN name DROP DEFAULT;
    END IF;
END $$;

-- Step 3: Update table comment
COMMENT ON TABLE hr_employees IS 'HR Employees - Minimal table for Upload Employees function only. Positions managed via hr_position_assignments, contacts via hr_employee_contacts.';

-- Verification query to check the table structure
SELECT column_name, data_type, is_nullable, column_default 
FROM information_schema.columns 
WHERE table_name = 'hr_employees' 
AND table_schema = 'public'
ORDER BY ordinal_position;