-- Check RLS on users table
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables 
WHERE tablename = 'users'
ORDER BY schemaname, tablename;

-- Check policies on users table
SELECT 
  policyname,
  permissive,
  qual,
  with_check
FROM pg_policies 
WHERE tablename = 'users'
ORDER BY policyname;
