-- =====================================================
-- FIX HR EMPLOYEES - ALLOW SAME EMPLOYEE ID IN DIFFERENT BRANCHES
-- =====================================================

-- The current constraint only allows unique employee_id globally
-- But the business rule is: same employee_id can exist in different branches
-- We need to change the constraint to be unique on (employee_id, branch_id)

-- Check current constraints
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'hr_employees'::regclass
AND contype = 'u'
ORDER BY conname;

-- Drop the existing unique constraint on employee_id only
ALTER TABLE hr_employees 
DROP CONSTRAINT hr_employees_employee_id_key;

-- Add a new composite unique constraint on (employee_id, branch_id)
-- This allows the same employee_id to exist in different branches
ALTER TABLE hr_employees 
ADD CONSTRAINT hr_employees_employee_id_branch_id_unique 
UNIQUE (employee_id, branch_id);

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_hr_employees_employee_id_branch_id 
ON hr_employees USING btree (employee_id, branch_id);

-- Verify the new constraint
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'hr_employees'::regclass
AND contype = 'u'
ORDER BY conname;

-- Test: Show current employees by branch
SELECT 
    employee_id,
    name,
    branch_id,
    COUNT(*) as count
FROM hr_employees 
GROUP BY employee_id, name, branch_id
ORDER BY employee_id, branch_id;