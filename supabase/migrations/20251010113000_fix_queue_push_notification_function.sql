-- Fix queue_push_notification function to only queue for users with push subscriptions
-- This ensures we only create notification queue entries for users who can actually receive push notifications

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS queue_push_notification(uuid);

-- Create improved function that only queues for users with active push subscriptions
CREATE OR REPLACE FUNCTION queue_push_notification(p_notification_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Insert notification queue entries only for users who have active push subscriptions
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
      -- Ensure we don't create duplicate queue entries
      AND NOT EXISTS (
          SELECT 1 FROM notification_queue nq 
          WHERE nq.notification_id = p_notification_id 
          AND nq.user_id = ps.user_id 
          AND nq.push_subscription_id = ps.id
      );

    -- Log the result
    RAISE NOTICE 'Queued push notifications for notification % to % users with active push subscriptions', 
        p_notification_id, 
        (SELECT COUNT(*) FROM notification_queue WHERE notification_id = p_notification_id);
        
END;
$$;

-- Add comment to document the function
COMMENT ON FUNCTION queue_push_notification(UUID) IS 
'Queue push notifications only for users who have active push subscriptions. 
This prevents creating queue entries for users who cannot receive push notifications.';

-- Create index to optimize the function performance
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active_user 
ON push_subscriptions (user_id, is_active) 
WHERE is_active = true;

-- Create index for faster notification queue lookups
CREATE INDEX IF NOT EXISTS idx_notification_queue_notification_user_subscription
ON notification_queue (notification_id, user_id, push_subscription_id);

-- Function and indexes created successfully