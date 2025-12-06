-- Check current RLS policies on receiving_records
SELECT 
  policyname, 
  permissive, 
  roles, 
  action,
  CASE 
    WHEN qual IS NULL THEN 'No USING clause'
    ELSE 'USING: ' || qual
  END as using_clause,
  CASE 
    WHEN with_check IS NULL THEN 'No WITH CHECK clause'
    ELSE 'WITH CHECK: ' || with_check
  END as with_check_clause
FROM pg_policies 
WHERE tablename = 'receiving_records'
ORDER BY action, policyname;

-- Check table RLS status
SELECT 
  tablename,
  rowsecurity as "RLS Enabled"
FROM pg_tables 
WHERE tablename = 'receiving_records';

-- Check if allow_all_operations policy exists
SELECT COUNT(*) as policy_count
FROM pg_policies 
WHERE tablename = 'receiving_records' 
AND policyname = 'allow_all_operations';
