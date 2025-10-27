-- Quick Diagnostic: Check what's causing the payment_status error
-- Run this in Supabase SQL Editor to identify the problem

-- 1. Check if payment_status column exists
SELECT 
    'Column Check' as check_type,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'vendor_payment_schedule'
        AND column_name = 'payment_status'
    ) THEN '❌ payment_status still exists!' 
    ELSE '✅ payment_status removed' 
    END as status;

-- 2. List all triggers on vendor_payment_schedule
SELECT 
    'Triggers' as check_type,
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'vendor_payment_schedule';

-- 3. List all functions that might reference payment_status
SELECT 
    'Functions' as check_type,
    p.proname as function_name,
    pg_get_functiondef(p.oid) as definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND (
    p.proname LIKE '%vendor_payment%'
    OR p.proname LIKE '%payment_status%'
    OR p.proname LIKE '%payment_schedule%'
);

-- 4. Check RLS policies on vendor_payment_schedule
SELECT 
    'RLS Policies' as check_type,
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'vendor_payment_schedule';

-- 5. Check table structure
SELECT 
    'Table Columns' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'vendor_payment_schedule'
ORDER BY ordinal_position;
