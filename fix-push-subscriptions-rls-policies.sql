-- Fix Push Subscriptions RLS Policies - Updated for Custom Authentication
-- This file adds the correct Row Level Security policies for the push_subscriptions table

-- Enable RLS on the push_subscriptions table
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies (cleanup)
DROP POLICY IF EXISTS "Users can view their own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Users can insert their own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Users can update their own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Users can delete their own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Service role can manage all push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Admins can view all push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Service role can access all push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Allow anon access temporarily" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Service role full access" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Authenticated users manage own subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Allow anon access for custom auth" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Authenticated users full access" ON public.push_subscriptions;

-- Policy 1: Service role has full access (for backend operations)
CREATE POLICY "Service role full access" ON public.push_subscriptions
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Allow anon role access (since your app uses custom auth with anon key)
CREATE POLICY "Allow anon access for custom auth" ON public.push_subscriptions
FOR ALL
TO anon
USING (true)
WITH CHECK (true);

-- Policy 3: Authenticated users full access (fallback for any Supabase Auth users)
CREATE POLICY "Authenticated users full access" ON public.push_subscriptions
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Verify RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'push_subscriptions' AND schemaname = 'public';

-- Verify policies are created
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'push_subscriptions' AND schemaname = 'public';