-- =====================================================
-- FIX HR EMPLOYEE CONTACTS - EMPLOYEE ID DATA TYPE
-- =====================================================

-- This needs to be run in Supabase SQL Editor to fix the data type mismatch

-- 1. First check current data types
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE (table_name = 'hr_employee_contacts' AND column_name = 'employee_id')
   OR (table_name = 'hr_employees' AND column_name = 'id')
ORDER BY table_name, column_name;

-- 2. Delete existing data to avoid type conversion issues
DELETE FROM hr_employee_contacts;

-- 3. Drop the foreign key constraint first
ALTER TABLE hr_employee_contacts 
DROP CONSTRAINT IF EXISTS hr_employee_contacts_employee_id_fkey;

-- 4. Change employee_id column type from uuid to match hr_employees.id
ALTER TABLE hr_employee_contacts 
ALTER COLUMN employee_id TYPE UUID USING NULL;

-- Note: The hr_employees table uses UUID for id, not VARCHAR as originally designed
-- So we keep hr_employee_contacts.employee_id as UUID to match hr_employees.id

-- 5. Add the foreign key constraint back
ALTER TABLE hr_employee_contacts 
ADD CONSTRAINT hr_employee_contacts_employee_id_fkey 
FOREIGN KEY (employee_id) REFERENCES hr_employees (id);

-- 6. Verify the changes
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE (table_name = 'hr_employee_contacts' AND column_name = 'employee_id')
   OR (table_name = 'hr_employees' AND column_name = 'id')
ORDER BY table_name, column_name;

-- 7. Check constraints
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'hr_employee_contacts'::regclass
AND contype = 'f'
ORDER BY conname;