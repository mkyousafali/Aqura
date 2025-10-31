-- Allow Service Worker (using anon key) to read from notification_queue
-- This is needed for push notifications to display correct content

-- Create policy to allow reading sent notifications
CREATE POLICY "Allow anonymous read of sent notifications in queue"
ON notification_queue
FOR SELECT
TO anon
USING (status = 'sent');

-- Grant select permission
GRANT SELECT ON notification_queue TO anon;

COMMENT ON POLICY "Allow anonymous read of sent notifications in queue" ON notification_queue 
IS 'Allows Service Worker to read sent notifications from queue to display push notification content';
