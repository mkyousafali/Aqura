-- Migration Validation Script
-- Run this after applying migrations to verify everything is working correctly

-- Check that all expected tables exist
SELECT 
    'Tables Check' as validation_type,
    COUNT(*) as actual_count,
    64 as expected_count,
    CASE WHEN COUNT(*) = 64 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE';

-- Check that all storage buckets exist
SELECT 
    'Storage Buckets Check' as validation_type,
    COUNT(*) as actual_count,
    14 as expected_count,
    CASE WHEN COUNT(*) = 14 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM storage.buckets;

-- Check that all views exist
SELECT 
    'Views Check' as validation_type,
    COUNT(*) as actual_count,
    5 as expected_count,
    CASE WHEN COUNT(*) >= 5 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM information_schema.views 
WHERE table_schema = 'public';

-- Check that all functions exist
SELECT 
    'Functions Check' as validation_type,
    COUNT(*) as actual_count,
    4 as expected_count,
    CASE WHEN COUNT(*) >= 4 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_type = 'FUNCTION'
AND routine_name IN ('set_updated_at', 'generate_notification_reference', 'generate_warning_reference', 'check_user_permission');

-- Check RLS is enabled on key tables
SELECT 
    'RLS Check' as validation_type,
    COUNT(*) as tables_with_rls,
    'N/A' as expected_count,
    CASE WHEN COUNT(*) > 50 THEN '✅ PASS' ELSE '⚠️ PARTIAL' END as status
FROM pg_tables 
WHERE schemaname = 'public' 
AND rowsecurity = true;

-- Check UUID extension is available
SELECT 
    'UUID Extension Check' as validation_type,
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp') 
         THEN '1' ELSE '0' END as actual_count,
    '1' as expected_count,
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'uuid-ossp') 
         THEN '✅ PASS' ELSE '❌ FAIL' END as status;

-- Test key functions work
SELECT 
    'Function Test' as validation_type,
    'Testing reference generators' as test_description,
    length(public.generate_warning_reference()) as result,
    CASE WHEN length(public.generate_warning_reference()) > 10 
         THEN '✅ PASS' ELSE '❌ FAIL' END as status;

-- Summary of all tables
SELECT 
    'Table Summary' as info_type,
    table_name,
    CASE WHEN is_insertable_into = 'YES' THEN '✅' ELSE '❌' END as insertable,
    table_type
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Summary message
SELECT 
    '🎉 Migration Validation Complete!' as message,
    'Review the results above to ensure all components are properly installed.' as instruction;