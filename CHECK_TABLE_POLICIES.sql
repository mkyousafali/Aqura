-- ============================================================================
-- CHECK ALL POLICIES ON A SINGLE TABLE
-- ============================================================================
-- Replace 'receiving_records' with any table name you want to check
-- ============================================================================

-- View all policies on a specific table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  qual as condition,
  with_check as insert_update_condition
FROM pg_policies
WHERE tablename = 'receiving_records'
ORDER BY policyname;

-- Alternative: More detailed view with operation types
SELECT 
  p.schemaname,
  p.tablename,
  p.policyname,
  CASE 
    WHEN p.qual IS NOT NULL THEN 'SELECT/UPDATE/DELETE'
    WHEN p.with_check IS NOT NULL THEN 'INSERT/UPDATE'
    ELSE 'ALL'
  END as operation_type,
  p.qual as read_condition,
  p.with_check as write_condition,
  p.permissive as is_permissive,
  ARRAY_TO_STRING(p.roles, ', ') as applicable_roles
FROM pg_policies p
WHERE p.tablename = 'receiving_records'
ORDER BY p.policyname;

-- Count total policies on this table
SELECT 
  tablename,
  COUNT(*) as total_policies,
  STRING_AGG(policyname, ', ' ORDER BY policyname) as policy_names
FROM pg_policies
WHERE tablename = 'receiving_records'
GROUP BY tablename;

-- ============================================================================
-- CHECK IF RLS IS ENABLED
-- ============================================================================

SELECT 
  schemaname,
  tablename,
  CASE WHEN rowsecurity THEN '✅ ENABLED' ELSE '❌ DISABLED' END as rls_status
FROM pg_tables
WHERE tablename = 'receiving_records'
AND schemaname = 'public';

-- ============================================================================
-- QUICK REFERENCE - CHANGE TABLE NAME BELOW
-- ============================================================================
-- Just change 'receiving_records' to check any other table:
-- Examples:
--   'branches'
--   'orders'
--   'products'
--   'tasks'
--   'users'
--   'vendors'
-- ============================================================================
