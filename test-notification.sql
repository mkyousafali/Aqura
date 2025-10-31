-- Create a test notification for user b658eca1-3cc1-48b2-bd3c-33b81fab5a0f
INSERT INTO notifications (
  title,
  body,
  created_by,
  target_type,
  target_users,
  icon,
  data
)
VALUES (
  'Test Push Notification',
  'This is a test notification to verify push notifications are working correctly.',
  'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b', -- madmin user ID
  'specific_users',
  ARRAY['b658eca1-3cc1-48b2-bd3c-33b81fab5a0f']::uuid[],
  '/icons/icon-192x192.png',
  jsonb_build_object(
    'url', '/notifications',
    'test', true,
    'timestamp', NOW()
  )
)
RETURNING id, title, created_at;

-- The trigger should automatically queue this notification
-- Wait a moment, then check the queue
SELECT 
  nq.id,
  nq.notification_id,
  nq.user_id,
  nq.status,
  nq.created_at,
  n.title
FROM notification_queue nq
JOIN notifications n ON n.id = nq.notification_id
WHERE nq.user_id = 'b658eca1-3cc1-48b2-bd3c-33b81fab5a0f'
ORDER BY nq.created_at DESC
LIMIT 5;
