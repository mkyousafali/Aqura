-- ============================================================
-- DIAGNOSE AND FIX 2X DUPLICATE ISSUE
-- ============================================================
-- Run this in Supabase SQL Editor to find the problem
-- ============================================================

-- Step 1: List ALL triggers on notifications table
SELECT 
    '📋 ALL TRIGGERS ON NOTIFICATIONS TABLE' as section,
    tgname as trigger_name,
    tgenabled as enabled,
    proname as function_name,
    CASE 
        WHEN tgtype & 2 = 2 THEN 'BEFORE'
        ELSE 'AFTER'
    END as timing,
    CASE 
        WHEN tgtype & 16 = 16 THEN 'INSERT'
        WHEN tgtype & 32 = 32 THEN 'UPDATE'
        WHEN tgtype & 64 = 64 THEN 'DELETE'
        ELSE 'OTHER'
    END as event,
    CASE 
        WHEN tgtype & 1 = 1 THEN 'FOR EACH ROW'
        ELSE 'FOR EACH STATEMENT'
    END as level
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'notifications'::regclass
AND NOT tgisinternal
ORDER BY tgname;

-- Step 2: Check if trigger_queue_push_notification exists multiple times
SELECT 
    '🔍 CHECKING FOR DUPLICATE trigger_queue_push_notification' as section,
    COUNT(*) as count,
    CASE 
        WHEN COUNT(*) = 0 THEN '❌ Trigger not found!'
        WHEN COUNT(*) = 1 THEN '✅ Perfect - only 1 trigger'
        ELSE '❌ PROBLEM: Multiple triggers with same name!'
    END as status
FROM pg_trigger
WHERE tgrelid = 'notifications'::regclass
AND tgname = 'trigger_queue_push_notification';

-- Step 3: Check if there are ANY triggers calling queue_push_notification
SELECT 
    '🔍 ALL TRIGGERS CALLING queue_push_notification FUNCTIONS' as section,
    tgname as trigger_name,
    proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'notifications'::regclass
AND (proname LIKE '%queue_push_notification%' OR proname LIKE '%push%notification%')
AND NOT tgisinternal;

-- ============================================================
-- SOLUTION: Drop ALL push-related triggers and recreate ONE
-- ============================================================

-- Drop everything
DO $$ 
DECLARE
    trigger_record RECORD;
BEGIN
    -- Find and drop all push-related triggers
    FOR trigger_record IN 
        SELECT DISTINCT t.tgname 
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        WHERE t.tgrelid = 'notifications'::regclass
        AND (p.proname LIKE '%queue_push%' OR p.proname LIKE '%push%notification%')
        AND NOT t.tgisinternal
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON notifications', trigger_record.tgname);
        RAISE NOTICE 'Dropped trigger: %', trigger_record.tgname;
    END LOOP;
END $$;

-- Recreate ONLY ONE trigger
CREATE TRIGGER trigger_queue_push_notification
    AFTER INSERT ON notifications
    FOR EACH ROW
    WHEN (NEW.status = 'published')
    EXECUTE FUNCTION queue_push_notification_trigger();

-- Verify result
SELECT 
    '✅ FINAL VERIFICATION' as section,
    COUNT(*) as trigger_count,
    CASE 
        WHEN COUNT(*) = 1 THEN '✅ SUCCESS - Only 1 trigger exists'
        WHEN COUNT(*) = 0 THEN '❌ FAILED - No trigger found'
        ELSE '❌ FAILED - Still have ' || COUNT(*) || ' triggers'
    END as status
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgrelid = 'notifications'::regclass
AND (p.proname LIKE '%queue_push%' OR p.proname LIKE '%push%notification%')
AND NOT t.tgisinternal;

-- List what we have now
SELECT 
    '📋 CURRENT PUSH TRIGGERS' as section,
    tgname as trigger_name,
    proname as function_name,
    tgenabled as enabled
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgrelid = 'notifications'::regclass
AND (p.proname LIKE '%queue_push%' OR p.proname LIKE '%push%notification%')
AND NOT t.tgisinternal;

-- ============================================================
-- TEST IT
-- ============================================================
-- Uncomment below to test (creates a test notification)
/*
DO $$
DECLARE
    v_notification_id uuid;
    v_queue_count integer;
BEGIN
    -- Create test notification
    INSERT INTO notifications (
        title, 
        message, 
        target_users, 
        target_type, 
        type, 
        priority, 
        status,
        created_by,
        created_by_name,
        created_by_role
    ) VALUES (
        'Test After Trigger Fix',
        'Should create ONLY 1 queue entry',
        ARRAY['b658eca1-3cc1-48b2-bd3c-33b81fab5a0f']::uuid[],
        'specific_users',
        'info',
        'medium',
        'published',
        'system',
        'Trigger Test',
        'Admin'
    ) RETURNING id INTO v_notification_id;
    
    -- Wait a moment
    PERFORM pg_sleep(1);
    
    -- Count queue entries
    SELECT COUNT(*) INTO v_queue_count
    FROM notification_queue
    WHERE notification_id = v_notification_id;
    
    RAISE NOTICE 'Test notification ID: %', v_notification_id;
    RAISE NOTICE 'Queue entries created: %', v_queue_count;
    
    IF v_queue_count = 1 THEN
        RAISE NOTICE '✅ SUCCESS - Only 1 queue entry created!';
    ELSIF v_queue_count = 0 THEN
        RAISE NOTICE '❌ FAILED - No queue entries created (trigger not working)';
    ELSE
        RAISE NOTICE '❌ FAILED - % queue entries created (still duplicating)', v_queue_count;
    END IF;
END $$;
*/
