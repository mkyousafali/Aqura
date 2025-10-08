-- Check notification_queue table schema and constraints
-- This will help identify the unique_notification_user_device constraint

-- 1. Show table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'notification_queue' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Show all constraints on notification_queue table
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    tc.is_deferrable,
    tc.initially_deferred
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
WHERE tc.table_name = 'notification_queue'
    AND tc.table_schema = 'public'
ORDER BY tc.constraint_type, tc.constraint_name;

-- 3. Show unique constraints specifically
SELECT 
    tc.constraint_name,
    string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) as columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'notification_queue'
    AND tc.constraint_type = 'UNIQUE'
    AND tc.table_schema = 'public'
GROUP BY tc.constraint_name;

-- 4. Show indexes on notification_queue
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'notification_queue'
    AND schemaname = 'public';

-- 5. Check if there are any composite unique constraints
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    array_agg(a.attname ORDER BY array_position(conkey, a.attnum)) as columns
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
WHERE t.relname = 'notification_queue'
    AND n.nspname = 'public'
    AND c.contype IN ('u', 'p')  -- unique and primary key constraints
GROUP BY c.conname, c.contype
ORDER BY c.contype, c.conname;