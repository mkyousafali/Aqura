-- Database Structure Diagnostic Script
-- Run this to see what's actually in your Supabase database

-- 1. Check if notifications table exists
SELECT 
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE tablename = 'notifications';

-- 2. Check all columns in notifications table
SELECT 
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'notifications' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. Check if enum types exist
SELECT 
    typname,
    typtype,
    enumlabel
FROM pg_type t
LEFT JOIN pg_enum e ON t.oid = e.enumtypid
WHERE typname LIKE '%notification%'
ORDER BY typname, enumsortorder;

-- 4. Check table constraints
SELECT 
    constraint_name,
    constraint_type,
    table_name,
    column_name
FROM information_schema.table_constraints tc
JOIN information_schema.constraint_column_usage ccu 
    ON tc.constraint_name = ccu.constraint_name
WHERE tc.table_name = 'notifications';

-- 5. Simple existence check
SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'notifications' 
      AND column_name = 'priority'
      AND table_schema = 'public'
) as priority_column_exists;

SELECT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'notifications' 
      AND column_name = 'status'
      AND table_schema = 'public'
) as status_column_exists;