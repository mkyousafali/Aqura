-- SQL to run in Supabase SQL Editor to fix the data type mismatch
-- This needs to be run manually in the Supabase dashboard

-- 1. First check current data types
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE (table_name = 'hr_fingerprint_transactions' AND column_name = 'branch_id')
   OR (table_name = 'branches' AND column_name = 'id')
ORDER BY table_name, column_name;

-- 2. Delete existing data to avoid type conversion issues
DELETE FROM hr_fingerprint_transactions;

-- 3. Change branch_id column type from uuid to bigint
ALTER TABLE hr_fingerprint_transactions 
ALTER COLUMN branch_id TYPE bigint USING NULL;

-- 4. Add foreign key constraint
ALTER TABLE hr_fingerprint_transactions 
ADD CONSTRAINT hr_fingerprint_transactions_branch_id_fkey 
FOREIGN KEY (branch_id) REFERENCES branches (id);

-- 5. Verify the changes
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE (table_name = 'hr_fingerprint_transactions' AND column_name = 'branch_id')
   OR (table_name = 'branches' AND column_name = 'id')
ORDER BY table_name, column_name;