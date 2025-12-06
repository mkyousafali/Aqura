-- Check for column-level security and other constraints
-- This might be blocking the REST API request

-- 1. Check if receiving_records table has any column constraints
SELECT 
  table_name,
  column_name,
  is_nullable,
  data_type,
  column_default
FROM information_schema.columns 
WHERE table_name = 'receiving_records'
ORDER BY ordinal_position;

-- 2. Check table permissions
SELECT grantee, privilege_type 
FROM information_schema.table_privileges 
WHERE table_name = 'receiving_records';

-- 3. Check if anon role has proper permissions
SELECT * FROM information_schema.role_table_grants 
WHERE table_name = 'receiving_records' 
AND grantee = 'anon';

-- 4. Check RLS status
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'receiving_records';
