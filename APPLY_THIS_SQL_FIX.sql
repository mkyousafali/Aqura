-- NOTIFICATION QUEUE CONSTRAINT FIX
-- ===================================
-- This script fixes the 409/400 notification delivery errors
-- by removing the overly restrictive unique constraint

-- 1. Check current constraints
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

-- 2. Remove the problematic constraint that prevents notification retries
ALTER TABLE notification_queue 
DROP CONSTRAINT IF EXISTS unique_notification_queue_entry;

-- Also drop the old constraint name if it exists
ALTER TABLE notification_queue 
DROP CONSTRAINT IF EXISTS unique_notification_user_device;

-- 3. Create performance index for common queries (if not exists)
CREATE INDEX IF NOT EXISTS idx_notification_queue_lookup 
ON notification_queue (notification_id, user_id, device_id, status);

-- 4. Verify constraints are removed
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

-- 5. Show current indexes
SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename = 'notification_queue'
    AND schemaname = 'public'
ORDER BY indexname;

-- SUCCESS MESSAGE
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'NOTIFICATION QUEUE CONSTRAINT FIX COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'The restrictive unique constraint has been removed.';
    RAISE NOTICE 'Notification retries should now work properly.';
    RAISE NOTICE '409/400 delivery errors should be resolved.';
    RAISE NOTICE '';
    RAISE NOTICE 'Performance index added for optimal queries.';
    RAISE NOTICE '';
END $$;