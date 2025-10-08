-- Updated Push Subscriptions RLS Policies 
-- This addresses authentication issues with the push_subscriptions table

-- Drop all existing policies first
DROP POLICY IF EXISTS "Users can view their own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Users can insert their own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Users can update their own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Users can delete their own push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Service role can manage all push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Admins can view all push subscriptions" ON public.push_subscriptions;
DROP POLICY IF EXISTS "Service role can access all push subscriptions" ON public.push_subscriptions;

-- Enable RLS if not already enabled
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Policy 1: Service role has full access (this should always work)
CREATE POLICY "Service role full access" ON public.push_subscriptions
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Authenticated users can manage their own subscriptions (simplified)
CREATE POLICY "Authenticated users manage own subscriptions" ON public.push_subscriptions
FOR ALL
TO authenticated
USING (
  user_id = auth.uid()::text::uuid OR 
  user_id = (auth.jwt() ->> 'user_id')::uuid OR
  auth.jwt() ->> 'role' = 'service_role'
)
WITH CHECK (
  user_id = auth.uid()::text::uuid OR 
  user_id = (auth.jwt() ->> 'user_id')::uuid OR
  auth.jwt() ->> 'role' = 'service_role'
);

-- Policy 3: Allow anon role for public functionality (temporarily for debugging)
CREATE POLICY "Allow anon access temporarily" ON public.push_subscriptions
FOR ALL
TO anon
USING (true)
WITH CHECK (true);

-- Verify the policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'push_subscriptions' AND schemaname = 'public'
ORDER BY policyname;

-- Test if RLS is working by checking table access
SELECT 
  tablename,
  rowsecurity as rls_enabled,
  hasoids
FROM pg_tables 
WHERE tablename = 'push_subscriptions' AND schemaname = 'public';