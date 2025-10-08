-- Fix notification_queue status constraint to include 'processing' and 'retry'
-- This addresses the 400 errors when updating notification status

-- First, drop the existing constraint
ALTER TABLE notification_queue DROP CONSTRAINT IF EXISTS notification_queue_status_check;

-- Add the updated constraint that includes all required status values
ALTER TABLE notification_queue 
ADD CONSTRAINT notification_queue_status_check 
CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'retry', 'processing'));

-- Verify the constraint was added correctly
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(c.oid) as constraint_definition
FROM pg_constraint c
JOIN pg_class t ON c.conrelid = t.oid
JOIN pg_namespace n ON t.relnamespace = n.oid
WHERE t.relname = 'notification_queue'
    AND n.nspname = 'public'
    AND c.contype = 'c'  -- check constraints
    AND conname = 'notification_queue_status_check'
ORDER BY c.conname;