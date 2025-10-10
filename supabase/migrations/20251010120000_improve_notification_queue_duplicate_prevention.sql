-- Improve notification queue duplicate prevention to include device_id
-- This prevents duplicates even when push_subscription_id changes but device_id remains the same

-- Drop existing function
DROP FUNCTION IF EXISTS queue_push_notification(uuid);

-- Create improved function with better duplicate prevention
CREATE OR REPLACE FUNCTION queue_push_notification(p_notification_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert notification queue entries only for users who have active push subscriptions
    -- Enhanced duplicate prevention includes device_id for better accuracy
    INSERT INTO notification_queue (
        notification_id,
        user_id,
        device_id,
        push_subscription_id,
        payload,
        status,
        created_at
    )
    SELECT 
        p_notification_id,
        ps.user_id,
        ps.device_id,
        ps.id as push_subscription_id,
        jsonb_build_object(
            'title', n.title,
            'body', n.message,
            'icon', '/icons/icon-192x192.png',
            'badge', '/icons/badge.png',
            'tag', 'notification-' || n.id::text,
            'data', jsonb_build_object(
                'notification_id', n.id,
                'url', '/notifications',
                'created_at', n.created_at,
                'type', n.type
            )
        ) as payload,
        'pending' as status,
        NOW() as created_at
    FROM notifications n
    CROSS JOIN push_subscriptions ps
    WHERE n.id = p_notification_id
      AND ps.is_active = true
      AND (
          -- For targeted notifications (to specific users)
          (n.target_type = 'specific_users' AND n.target_users IS NOT NULL AND jsonb_array_length(n.target_users) > 0 AND ps.user_id::text = ANY(SELECT jsonb_array_elements_text(n.target_users)))
          OR
          -- For branch notifications (to users in specific branches)
          (n.target_type = 'specific_branches' AND n.target_branches IS NOT NULL AND jsonb_array_length(n.target_branches) > 0 AND EXISTS (
              SELECT 1 FROM users u 
              WHERE u.id = ps.user_id 
              AND u.branch_id::text = ANY(SELECT jsonb_array_elements_text(n.target_branches))
          ))
          OR
          -- For broadcast notifications (to all users)
          (n.target_type = 'all_users')
      )
      -- STRICT DUPLICATE PREVENTION: All 4 fields must match exactly
      -- Only prevents duplicates when notification_id + user_id + push_subscription_id + device_id ALL match
      AND NOT EXISTS (
          SELECT 1 FROM notification_queue nq 
          WHERE nq.notification_id = p_notification_id 
          AND nq.user_id = ps.user_id 
          AND nq.push_subscription_id = ps.id
          AND nq.device_id = ps.device_id
      );

    -- Log the result with strict duplicate prevention information
    RAISE NOTICE 'Queued push notifications for notification % to % users with active push subscriptions (strict 4-field duplicate prevention)', 
        p_notification_id, 
        (SELECT COUNT(*) FROM notification_queue WHERE notification_id = p_notification_id);
        
END;
$$;

-- Add enhanced comment to document the improved function
COMMENT ON FUNCTION queue_push_notification(UUID) IS 
'Queue push notifications only for users who have active push subscriptions.
Strict duplicate prevention: only prevents duplicates when ALL 4 fields match exactly:
notification_id + user_id + push_subscription_id + device_id';

-- Create single optimized index for the 4-field duplicate check
CREATE INDEX IF NOT EXISTS idx_notification_queue_duplicate_prevention
ON notification_queue (notification_id, user_id, push_subscription_id, device_id);

-- Add index for cleanup and monitoring queries
CREATE INDEX IF NOT EXISTS idx_notification_queue_status_created
ON notification_queue (status, created_at);

-- Function and strict 4-field duplicate prevention index created successfully
-- Only prevents duplicates when ALL 4 fields match: notification_id + user_id + push_subscription_id + device_id