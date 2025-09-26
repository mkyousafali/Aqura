-- =====================================================
-- FIX HR EMPLOYEES - BRANCH ID DATA TYPE MISMATCH
-- =====================================================

-- Check current data types
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE (table_name = 'hr_employees' AND column_name = 'branch_id')
   OR (table_name = 'branches' AND column_name = 'id')
ORDER BY table_name, column_name;

-- Fix the data type mismatch by changing hr_employees.branch_id from uuid to bigint
-- First, check if there's any existing data
SELECT COUNT(*) as employee_count FROM hr_employees;

-- Delete existing data to avoid type conversion issues (if table is not empty)
-- WARNING: This will delete existing employee data
-- DELETE FROM hr_employees;

-- Change branch_id column type from uuid to bigint
ALTER TABLE hr_employees 
ALTER COLUMN branch_id TYPE bigint USING NULL;

-- Add foreign key constraint if it doesn't exist
ALTER TABLE hr_employees 
ADD CONSTRAINT hr_employees_branch_id_fkey 
FOREIGN KEY (branch_id) REFERENCES branches (id);

-- Verify the changes
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'hr_employees'::regclass
AND contype = 'f'
AND conname LIKE '%branch%'
ORDER BY conname;

-- Check final data types
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE (table_name = 'hr_employees' AND column_name = 'branch_id')
   OR (table_name = 'branches' AND column_name = 'id')
ORDER BY table_name, column_name;