-- Check RLS and permissions on system_api_keys table
\echo '=== TABLE EXISTENCE ===' 
SELECT tablename FROM pg_tables WHERE tablename = 'system_api_keys' AND schemaname = 'public';

\echo ''
\echo '=== RLS STATUS ===' 
SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE tablename = 'system_api_keys';

\echo ''
\echo '=== RLS POLICIES ===' 
SELECT schemaname, tablename, policyname, permissive, roles, qual, with_check FROM pg_policies WHERE tablename = 'system_api_keys';

\echo ''
\echo '=== TABLE GRANTS ===' 
SELECT grantee, privilege_type FROM information_schema.table_privileges WHERE table_name = 'system_api_keys' AND table_schema = 'public';

\echo ''
\echo '=== SAMPLE DATA ===' 
SELECT id, service_name, is_active, created_at FROM public.system_api_keys LIMIT 5;
