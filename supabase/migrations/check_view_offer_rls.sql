-- Check RLS policies on view_offer table

SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'view_offer'
ORDER BY policyname;

-- Also check if RLS is enabled
SELECT
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'view_offer';
