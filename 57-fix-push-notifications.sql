-- Fix Push Notification System
-- Add missing delivery_status column and fix related issues

-- 1. Add delivery_status column to notification_recipients table
ALTER TABLE notification_recipients 
ADD COLUMN IF NOT EXISTS delivery_status VARCHAR(20) DEFAULT 'pending';

-- 2. Add delivery_attempted_at column for tracking delivery attempts  
ALTER TABLE notification_recipients 
ADD COLUMN IF NOT EXISTS delivery_attempted_at TIMESTAMPTZ NULL;

-- 3. Add error_message column for tracking delivery errors
ALTER TABLE notification_recipients 
ADD COLUMN IF NOT EXISTS error_message TEXT NULL;

-- 4. Create an index on delivery_status for better performance
CREATE INDEX IF NOT EXISTS idx_notification_recipients_delivery_status 
ON notification_recipients(delivery_status) 
WHERE delivery_status IN ('pending', 'failed');

-- 5. Update existing records to have proper delivery_status
UPDATE notification_recipients 
SET delivery_status = CASE 
    WHEN is_read = true THEN 'delivered'
    WHEN is_dismissed = true THEN 'delivered' 
    ELSE 'pending'
END
WHERE delivery_status = 'pending';

-- 6. Test the fixed structure
SELECT 'Fixed Notification Recipients Check:' as test;
SELECT 
    nr.id,
    nr.notification_id,
    nr.user_id,
    nr.delivery_status,
    nr.is_read,
    nr.is_dismissed,
    nr.created_at,
    n.title,
    n.type
FROM notification_recipients nr
JOIN notifications n ON nr.notification_id = n.id
ORDER BY nr.created_at DESC
LIMIT 5;