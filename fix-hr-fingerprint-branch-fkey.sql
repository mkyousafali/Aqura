-- =====================================================
-- FIX HR FINGERPRINT TRANSACTIONS - BRANCH ID DATA TYPE
-- =====================================================

-- First, check the current data types
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE (table_name = 'hr_fingerprint_transactions' AND column_name = 'branch_id')
   OR (table_name = 'branches' AND column_name = 'id')
ORDER BY table_name, column_name;

-- Fix the data type mismatch by changing branch_id from uuid to bigint
-- First, drop any existing data (if any) to avoid type conversion issues
-- WARNING: This will delete existing fingerprint data
DELETE FROM hr_fingerprint_transactions;

-- Change branch_id column type from uuid to bigint
ALTER TABLE hr_fingerprint_transactions 
ALTER COLUMN branch_id TYPE bigint USING NULL;

-- Add the foreign key constraint for branch_id to reference branches table
ALTER TABLE hr_fingerprint_transactions 
ADD CONSTRAINT hr_fingerprint_transactions_branch_id_fkey 
FOREIGN KEY (branch_id) REFERENCES branches (id);

-- Verify the constraint was added
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'hr_fingerprint_transactions'::regclass
AND contype = 'f'
ORDER BY conname;

-- Check the final data types
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE (table_name = 'hr_fingerprint_transactions' AND column_name = 'branch_id')
   OR (table_name = 'branches' AND column_name = 'id')
ORDER BY table_name, column_name;