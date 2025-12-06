-- ============================================================================
-- DISABLE ALL RLS AND CONSTRAINTS TO TEST
-- ============================================================================
-- If the INSERT still fails with RLS disabled, it's a constraint issue
-- ============================================================================

-- Step 1: DISABLE RLS completely
ALTER TABLE receiving_records DISABLE ROW LEVEL SECURITY;

-- Step 2: Check foreign key constraints
SELECT 
  constraint_name,
  table_name,
  column_name,
  foreign_table_name,
  foreign_column_name
FROM information_schema.key_column_usage
WHERE table_name = 'receiving_records' 
  AND foreign_table_name IS NOT NULL
ORDER BY constraint_name;

-- Step 3: Check if referenced tables have data
SELECT COUNT(*) as vendors_count FROM vendors;
SELECT COUNT(*) as branches_count FROM branches;
SELECT COUNT(*) as users_count FROM users;

-- ============================================================================
-- TEST NOW:
-- Try to INSERT a receiving record
-- 
-- If it works with RLS disabled:
--   -> Problem WAS RLS (but we fixed it)
-- 
-- If it STILL fails with RLS disabled:
--   -> Problem is a FOREIGN KEY CONSTRAINT
--   -> Check: branch_id, vendor_id, user_id
--   -> Make sure they exist in their respective tables
-- ============================================================================
