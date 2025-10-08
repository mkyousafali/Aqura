-- Fix the duplicate key constraint issue in notification_queue
-- The unique_notification_user_device constraint is too restrictive for our use case

-- 1. First, check current data that might be affected
SELECT 
    notification_id,
    user_id,
    device_id,
    COUNT(*) as duplicate_count
FROM notification_queue
GROUP BY notification_id, user_id, device_id
HAVING COUNT(*) > 1;

-- 2. Drop the problematic unique constraint
ALTER TABLE notification_queue 
DROP CONSTRAINT IF EXISTS unique_notification_user_device;

-- 3. Instead, create a more appropriate unique constraint that allows retries
-- This prevents true duplicates but allows legitimate retry scenarios
-- We'll use a combination that includes the created_at timestamp to make it unique
ALTER TABLE notification_queue 
ADD CONSTRAINT unique_notification_queue_entry 
UNIQUE (notification_id, user_id, device_id, created_at);

-- Alternative approach: If we want to allow multiple attempts but prevent exact duplicates
-- We could drop the constraint entirely and handle duplicates in application logic
-- ALTER TABLE notification_queue DROP CONSTRAINT IF EXISTS unique_notification_queue_entry;

-- 4. Create an index for performance on the commonly queried columns
CREATE INDEX IF NOT EXISTS idx_notification_queue_lookup 
ON notification_queue (notification_id, user_id, device_id, status);

-- 5. Verify the constraint is removed
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    array_agg(a.attname ORDER BY array_position(conkey, a.attnum)) as columns
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = ANY(c.conkey)
WHERE t.relname = 'notification_queue'
    AND n.nspname = 'public'
    AND c.contype = 'u'  -- unique constraints only
GROUP BY c.conname, c.contype
ORDER BY c.conname;