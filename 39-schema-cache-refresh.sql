-- Schema Cache Refresh Script
-- Run this in Supabase SQL Editor to force schema cache refresh

-- Force schema cache refresh by reloading PostgREST
NOTIFY pgrst, 'reload schema';

-- Alternative: Query system tables to verify column exists
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'notifications' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if notifications table exists with correct structure
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