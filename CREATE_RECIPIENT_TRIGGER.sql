-- ============================================================
-- FIX: CREATE MISSING RECIPIENT CREATION TRIGGER
-- ============================================================
-- This is the missing piece! Recipients must be created BEFORE
-- the queue_push_notification trigger can work.
-- ============================================================

-- Step 1: Create function to populate notification_recipients
CREATE OR REPLACE FUNCTION create_notification_recipients()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id uuid;
    v_role text;
    v_branch_id uuid;
BEGIN
    -- Handle specific users
    IF NEW.target_type = 'specific_users' AND NEW.target_users IS NOT NULL THEN
        FOR v_user_id IN
            SELECT (jsonb_array_elements_text(NEW.target_users))::uuid
        LOOP
            INSERT INTO notification_recipients (
                notification_id,
                user_id,
                delivery_status,
                created_at
            ) VALUES (
                NEW.id,
                v_user_id,
                'pending',
                NOW()
            );
        END LOOP;
    END IF;

    -- Handle roles
    IF NEW.target_type = 'roles' AND NEW.target_roles IS NOT NULL THEN
        FOR v_user_id IN
            SELECT id FROM users
            WHERE role IN (SELECT jsonb_array_elements_text(NEW.target_roles))
            AND deleted_at IS NULL
        LOOP
            INSERT INTO notification_recipients (
                notification_id,
                user_id,
                delivery_status,
                created_at
            ) VALUES (
                NEW.id,
                v_user_id,
                'pending',
                NOW()
            );
        END LOOP;
    END IF;

    -- Handle branches
    IF NEW.target_type = 'branches' AND NEW.target_branches IS NOT NULL THEN
        FOR v_user_id IN
            SELECT DISTINCT user_id FROM user_branches
            WHERE branch_id IN (SELECT (jsonb_array_elements_text(NEW.target_branches))::uuid)
            AND deleted_at IS NULL
        LOOP
            INSERT INTO notification_recipients (
                notification_id,
                user_id,
                delivery_status,
                created_at
            ) VALUES (
                NEW.id,
                v_user_id,
                'pending',
                NOW()
            );
        END LOOP;
    END IF;

    -- Handle all users
    IF NEW.target_type = 'all_users' THEN
        FOR v_user_id IN
            SELECT id FROM users
            WHERE deleted_at IS NULL
        LOOP
            INSERT INTO notification_recipients (
                notification_id,
                user_id,
                delivery_status,
                created_at
            ) VALUES (
                NEW.id,
                v_user_id,
                'pending',
                NOW()
            );
        END LOOP;
    END IF;

    RAISE NOTICE 'Created recipients for notification %', NEW.id;
    RETURN NEW;
END;
$$;

-- Step 2: Create trigger to call this function BEFORE queue_push_notification
DROP TRIGGER IF EXISTS trigger_create_notification_recipients ON notifications;

CREATE TRIGGER trigger_create_notification_recipients
    AFTER INSERT ON notifications
    FOR EACH ROW
    WHEN (NEW.status = 'published')
    EXECUTE FUNCTION create_notification_recipients();

-- Step 3: Verify both triggers exist in correct order
SELECT 
    '✅ VERIFICATION' as check_name,
    tgname as trigger_name,
    proname as function_name,
    CASE 
        WHEN tgname = 'trigger_create_notification_recipients' THEN '1️⃣ First - Creates recipients'
        WHEN tgname = 'trigger_queue_push_notification' THEN '2️⃣ Second - Queues push'
        ELSE 'Other'
    END as execution_order
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgrelid = 'notifications'::regclass
AND NOT tgisinternal
ORDER BY tgname;

-- Step 4: TEST with a real notification
DO $$
DECLARE
    v_notification_id uuid;
    v_recipient_count integer;
    v_queue_count integer;
BEGIN
    RAISE NOTICE '🧪 TESTING COMPLETE FLOW...';
    
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
        'Complete Flow Test',
        'Testing recipient creation + queue',
        '["b658eca1-3cc1-48b2-bd3c-33b81fab5a0f"]'::jsonb,
        'specific_users',
        'info',
        'medium',
        'published',
        'system',
        'System Test',
        'Admin'
    ) RETURNING id INTO v_notification_id;
    
    -- Wait for triggers
    PERFORM pg_sleep(1);
    
    -- Count recipients
    SELECT COUNT(*) INTO v_recipient_count
    FROM notification_recipients
    WHERE notification_id = v_notification_id;
    
    -- Count queue entries
    SELECT COUNT(*) INTO v_queue_count
    FROM notification_queue
    WHERE notification_id = v_notification_id;
    
    RAISE NOTICE '📊 Test Results:';
    RAISE NOTICE '  Notification ID: %', v_notification_id;
    RAISE NOTICE '  Recipients created: %', v_recipient_count;
    RAISE NOTICE '  Queue entries created: %', v_queue_count;
    
    IF v_recipient_count = 1 AND v_queue_count = 1 THEN
        RAISE NOTICE '✅ SUCCESS! Complete flow working!';
    ELSIF v_recipient_count = 0 THEN
        RAISE NOTICE '❌ FAILED: No recipients created';
    ELSIF v_queue_count = 0 THEN
        RAISE NOTICE '❌ FAILED: Recipients created but no queue entries';
    ELSIF v_queue_count > 1 THEN
        RAISE NOTICE '⚠️  WARNING: % queue entries (should be 1)', v_queue_count;
    ELSE
        RAISE NOTICE '❓ UNEXPECTED RESULT';
    END IF;
END $$;

-- ============================================================
-- EXPLANATION:
-- ============================================================
-- This creates the missing link in the chain:
--
-- BEFORE (broken):
-- INSERT notification → queue_push_notification_trigger
--                    ↓ Looks for recipients (finds 0)
--                    ↓ Creates 0 queue entries ❌
--
-- AFTER (fixed):
-- INSERT notification → create_notification_recipients (NEW!)
--                    ↓ Creates recipient records ✅
--                    → queue_push_notification_trigger
--                    ↓ Finds recipients
--                    ↓ Creates queue entries ✅
-- ============================================================
