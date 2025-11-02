-- =====================================================
-- DIAGNOSTIC QUERY: Check trigger function definition
-- =====================================================
-- Run this in Supabase SQL Editor to see what the trigger does
-- =====================================================

-- 1. Check if the function exists and get its definition
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition,
    p.prosrc as function_source
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'trigger_sync_erp_reference_on_task_completion'
AND n.nspname = 'public';

-- 2. Check all triggers on task_completions table
SELECT 
    t.tgname as trigger_name,
    t.tgenabled as is_enabled,
    p.proname as function_name,
    pg_get_triggerdef(t.oid) as trigger_definition
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE c.relname = 'task_completions'
AND t.tgname NOT LIKE 'RI_%'
AND t.tgisinternal = false;

-- 3. Check the task_completions table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'task_completions' 
AND table_schema = 'public'
ORDER BY ordinal_position;
