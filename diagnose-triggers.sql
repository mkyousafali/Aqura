-- Diagnostic Script: Check for triggers and functions referencing payment_status
-- Run this to identify what's causing the error

-- 1. List all triggers on vendor_payment_schedule
SELECT 
    trigger_name,
    event_manipulation,
    action_statement,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'vendor_payment_schedule'
AND event_object_schema = 'public'
ORDER BY trigger_name;

-- 2. List all functions that might be related to vendor_payment_schedule
SELECT 
    n.nspname as schema_name,
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND (
    p.proname LIKE '%vendor_payment%' 
    OR p.proname LIKE '%payment_status%'
    OR p.proname LIKE '%payment_schedule%'
)
ORDER BY p.proname;

-- 3. Check if payment_status column still exists
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'vendor_payment_schedule'
AND column_name = 'payment_status';

-- 4. List all columns in vendor_payment_schedule
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'vendor_payment_schedule'
ORDER BY ordinal_position;
