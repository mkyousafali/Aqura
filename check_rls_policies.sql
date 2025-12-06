-- Check RLS policies on receiving_records table
SELECT 
  schemaname, 
  tablename, 
  policyname, 
  permissive, 
  roles, 
  qual as using_clause, 
  with_check
FROM pg_policies 
WHERE tablename = 'receiving_records' 
ORDER BY policyname;

-- Also check if RLS is actually enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'receiving_records';
