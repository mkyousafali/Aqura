-- ============================================================================
-- CHECK SUPABASE INTERNAL PERMISSIONS
-- ============================================================================

-- Check if there are any additional permission policies or grants
SELECT 
  grantee,
  privilege_type,
  is_grantable
FROM information_schema.table_privileges
WHERE table_name = 'receiving_records'
ORDER BY grantee, privilege_type;

-- Check roles
SELECT 
  rolname,
  rolsuper,
  rolinherit,
  rolcreaterole,
  rolcreatedb
FROM pg_roles
WHERE rolname IN ('authenticated', 'anon', 'service_role')
ORDER BY rolname;

-- ============================================================================
-- Check if there are row security violations
-- ============================================================================
-- Run as anon user to see if the policy is being enforced
-- This requires you to have set up row-level security correctly
-- ============================================================================
