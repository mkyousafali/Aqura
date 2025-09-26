-- =====================================================
-- FIX HR POSITION ASSIGNMENTS - ADD BRANCH FOREIGN KEY
-- =====================================================

-- First, check the current data types
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE (table_name = 'hr_position_assignments' AND column_name = 'branch_id')
   OR (table_name = 'branches' AND column_name = 'id')
ORDER BY table_name, column_name;

-- Fix the data type mismatch by changing branch_id from uuid to bigint
-- First, drop any existing data (if any) to avoid type conversion issues
-- WARNING: This will delete existing assignment data
DELETE FROM hr_position_assignments;

-- Change branch_id column type from uuid to bigint
ALTER TABLE hr_position_assignments 
ALTER COLUMN branch_id TYPE bigint USING NULL;

-- Add the foreign key constraint for branch_id to reference branches table
ALTER TABLE hr_position_assignments 
ADD CONSTRAINT hr_position_assignments_branch_id_fkey 
FOREIGN KEY (branch_id) REFERENCES branches (id);

-- Add index for performance on branch_id
CREATE INDEX IF NOT EXISTS idx_hr_assignments_branch_id 
ON hr_position_assignments USING btree (branch_id);

-- Verify the constraint was added
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'hr_position_assignments'::regclass
AND contype = 'f'
ORDER BY conname;

-- Verify existing branches
SELECT id, name_en, name_ar, location_en, location_ar, is_main_branch 
FROM branches 
ORDER BY is_main_branch DESC, name_en;

-- Check the final data types
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE (table_name = 'hr_position_assignments' AND column_name = 'branch_id')
   OR (table_name = 'branches' AND column_name = 'id')
ORDER BY table_name, column_name;