-- Fix RLS on notification_queue table to allow Edge Functions to access it
-- This is required for the process-push-queue Edge Function to work

-- Disable RLS entirely on notification_queue since it's a system table
-- Edge Functions need full access to manage the queue
ALTER TABLE notification_queue DISABLE ROW LEVEL SECURITY;

-- Also disable RLS on push_subscriptions for Edge Function access
ALTER TABLE push_subscriptions DISABLE ROW LEVEL SECURITY;

-- Add comment explaining why RLS is disabled
COMMENT ON TABLE notification_queue IS 'System table for push notification queue - RLS disabled for Edge Function access';
COMMENT ON TABLE push_subscriptions IS 'Push subscription management - RLS disabled for Edge Function access';
