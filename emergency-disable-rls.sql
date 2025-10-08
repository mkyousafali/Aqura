-- Emergency Push Subscriptions RLS Fix
-- This completely disables RLS temporarily to test if that's the issue

-- Option 1: Temporarily disable RLS entirely (for testing)
ALTER TABLE public.push_subscriptions DISABLE ROW LEVEL SECURITY;

-- Check if RLS is now disabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'push_subscriptions' AND schemaname = 'public';

-- Show current policies (should be empty after disable)
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'push_subscriptions' AND schemaname = 'public';