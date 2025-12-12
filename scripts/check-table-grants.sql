-- Check table grants and permissions for anon/public role

-- Check what privileges exist on button tables vs branches
SELECT 
  table_catalog,
  table_schema,
  table_name,
  privilege_type,
  is_grantable,
  grantee
FROM information_schema.role_table_grants
WHERE (table_name LIKE 'button_%' OR table_name = 'branches')
  AND table_schema = 'public'
ORDER BY table_name, privilege_type, grantee;

-- Alternative: Check table ACLs directly (detailed view)
SELECT 
  schemaname,
  tablename,
  (aclexplode(relacl)).* as acl_entry
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
JOIN pg_namespace n ON n.oid = c.relnamespace AND n.nspname = t.schemaname
WHERE (t.tablename LIKE 'button_%' OR t.tablename = 'branches')
  AND t.schemaname = 'public';

-- Check specific roles and their table permissions
SELECT 
  grantee,
  privilege_type,
  table_name
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('button_main_sections', 'button_sub_sections', 'sidebar_buttons', 'button_permissions', 'branches')
ORDER BY table_name, grantee, privilege_type;
