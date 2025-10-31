-- Create function to queue push notifications when a notification is created
-- This function is called from the frontend after creating a notification

CREATE OR REPLACE FUNCTION queue_push_notification(p_notification_id UUID)
RETURNS TABLE (
  queued_count INTEGER,
  target_users TEXT[]
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_notification RECORD;
  v_user_id UUID;
  v_user_ids UUID[];
  v_queued_count INTEGER := 0;
BEGIN
  -- Get the notification details
  SELECT * INTO v_notification
  FROM notifications
  WHERE id = p_notification_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Notification not found: %', p_notification_id;
  END IF;

  -- Determine target users based on target_type
  IF v_notification.target_type = 'all' THEN
    -- Get all active users
    SELECT ARRAY_AGG(id) INTO v_user_ids
    FROM users
    WHERE status = 'active';
    
  ELSIF v_notification.target_type = 'specific' THEN
    -- Use the specific target_users array
    v_user_ids := v_notification.target_users;
    
  ELSIF v_notification.target_type = 'role' THEN
    -- Get users by role
    SELECT ARRAY_AGG(id) INTO v_user_ids
    FROM users
    WHERE user_type = ANY(v_notification.target_roles)
      AND status = 'active';
      
  ELSIF v_notification.target_type = 'branch' THEN
    -- Get users by branch
    SELECT ARRAY_AGG(id) INTO v_user_ids
    FROM users
    WHERE branch_id = ANY(v_notification.target_branches)
      AND status = 'active';
  END IF;

  -- Return empty if no target users
  IF v_user_ids IS NULL OR array_length(v_user_ids, 1) IS NULL THEN
    RETURN QUERY SELECT 0, ARRAY[]::TEXT[];
    RETURN;
  END IF;

  -- Create notification queue entries for each user's active push subscriptions
  FOR v_user_id IN SELECT UNNEST(v_user_ids) LOOP
    -- Insert queue entry for each active push subscription
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
      v_user_id,
      ps.device_id,
      ps.id,
      jsonb_build_object(
        'title', v_notification.title,
        'body', v_notification.message,
        'icon', '/icons/icon-192x192.png',
        'badge', '/icons/icon-192x192.png',
        'tag', 'notification-' || p_notification_id::text,
        'data', jsonb_build_object(
          'notification_id', p_notification_id,
          'type', v_notification.type,
          'priority', v_notification.priority,
          'url', '/notifications'
        )
      ),
      'pending',
      NOW()
    FROM push_subscriptions ps
    WHERE ps.user_id = v_user_id
      AND ps.is_active = true;
    
    GET DIAGNOSTICS v_queued_count = ROW_COUNT;
  END LOOP;

  -- Update the notification with total recipients count
  UPDATE notifications
  SET total_recipients = array_length(v_user_ids, 1)
  WHERE id = p_notification_id;

  -- Return summary
  RETURN QUERY 
  SELECT 
    v_queued_count,
    ARRAY(SELECT v_user_id::TEXT FROM UNNEST(v_user_ids) AS v_user_id);
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION queue_push_notification(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION queue_push_notification(UUID) TO service_role;

-- Add comment
COMMENT ON FUNCTION queue_push_notification IS 'Queue push notifications for a notification to all target users with active push subscriptions';
