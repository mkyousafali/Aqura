-- ================================================================
-- FIX: Notification Recipients Trigger Function
-- Date: 2025-11-06
-- Description: Fix the create_notification_recipients function to work with actual table schemas
-- ================================================================

-- Drop and recreate the function with correct table references
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

    -- Handle roles - FIXED: removed deleted_at reference, use status instead
    IF NEW.target_type = 'roles' AND NEW.target_roles IS NOT NULL THEN
        FOR v_user_id IN
            SELECT id FROM users
            WHERE role_type::text IN (SELECT jsonb_array_elements_text(NEW.target_roles))
            AND status = 'active'
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

    -- Handle branches - FIXED: use users.branch_id directly since user_branches table doesn't exist
    IF NEW.target_type = 'branches' AND NEW.target_branches IS NOT NULL THEN
        FOR v_user_id IN
            SELECT id FROM users
            WHERE branch_id IN (SELECT (jsonb_array_elements_text(NEW.target_branches))::bigint)
            AND status = 'active'
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

    -- Handle all users - FIXED: removed deleted_at reference, use status instead
    IF NEW.target_type = 'all_users' THEN
        FOR v_user_id IN
            SELECT id FROM users
            WHERE status = 'active'
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

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION create_notification_recipients() TO authenticated;
GRANT EXECUTE ON FUNCTION create_notification_recipients() TO anon;

-- ================================================================
-- COMPLETED FIX
-- ================================================================