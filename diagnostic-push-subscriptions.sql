-- Diagnostic check for push_subscriptions table issues
-- This will help identify why we're getting 406 errors

-- Check if table exists and basic info
SELECT 
    schemaname,
    tablename,
    hasindexes,
    hasrules,
    hastriggers,
    rowsecurity
FROM pg_tables 
WHERE tablename = 'push_subscriptions' AND schemaname = 'public';

-- Check table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'push_subscriptions' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check constraints
SELECT 
    constraint_name,
    constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'push_subscriptions' 
AND table_schema = 'public';

-- Test a simple SELECT query
SELECT COUNT(*) as total_records FROM public.push_subscriptions;

-- Check if there are any foreign key issues
SELECT 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_name='push_subscriptions';