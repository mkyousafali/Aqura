-- Precise Notifications Table Investigation
-- This will show us exactly what's in the actual table

-- 1. Show ALL tables in public schema
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename LIKE '%notification%'
ORDER BY tablename;

-- 2. Show EXACT structure of notifications table
SELECT 
    a.attname as column_name,
    pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type,
    a.attnotnull as not_null,
    a.atthasdef as has_default
FROM pg_catalog.pg_attribute a
WHERE a.attrelid = (
    SELECT c.oid 
    FROM pg_catalog.pg_class c 
    LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace 
    WHERE c.relname = 'notifications' 
      AND n.nspname = 'public'
)
AND a.attnum > 0 
AND NOT a.attisdropped
ORDER BY a.attnum;

-- 3. Try to select just the basic columns
SELECT 
    id,
    title,
    message
FROM notifications 
LIMIT 1;

-- 4. Show table definition using pg_dump style
SELECT 
    'CREATE TABLE public.notifications (' ||
    string_agg(
        column_name || ' ' || data_type ||
        CASE 
            WHEN is_nullable = 'NO' THEN ' NOT NULL'
            ELSE ''
        END ||
        CASE 
            WHEN column_default IS NOT NULL THEN ' DEFAULT ' || column_default
            ELSE ''
        END,
        ', '
        ORDER BY ordinal_position
    ) || ');' as create_statement
FROM information_schema.columns 
WHERE table_name = 'notifications' 
  AND table_schema = 'public';