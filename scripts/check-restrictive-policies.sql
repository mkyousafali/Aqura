-- Check for RESTRICTIVE policies
SELECT 
  tablename,
  policyname,
  permissive
FROM pg_policies
WHERE tablename LIKE 'button_%'
AND permissive = 'RESTRICTIVE'
ORDER BY tablename;

-- Check for triggers
SELECT 
  tablename,
  trigname,
  tgtype
FROM pg_trigger
WHERE tablename LIKE 'button_%'
ORDER BY tablename, trigname;

-- Check table grants
SELECT 
  grantee,
  privilege_type,
  table_name,
  is_grantable
FROM role_table_grants
WHERE table_name LIKE 'button_%'
ORDER BY table_name, grantee;
