-- ============================================================================
-- DIAGNOSTIC: IS THE USER AUTHENTICATED?
-- ============================================================================
-- Your RLS is checking: auth.uid() IS NOT NULL
-- But you're using CUSTOM authentication (persistentAuth), not Supabase Auth
--
-- This means auth.uid() will ALWAYS return NULL in your case!
-- ============================================================================

-- Solution: Use Supabase Auth OR change the RLS policy
-- For now, let's create a policy that doesn't require authentication

-- Drop the current policies
DROP POLICY IF EXISTS "authenticated_users_full_access" ON receiving_records;
DROP POLICY IF EXISTS "anon_full_access" ON receiving_records;

-- Create a new policy that allows ALL operations (for testing/development)
-- WARNING: This is NOT secure for production - everyone can access this table
CREATE POLICY "allow_all_operations" ON receiving_records 
  FOR ALL 
  USING (true)
  WITH CHECK (true);

-- Verify
SELECT 
  policyname,
  cmd as "Operation",
  qual as "USING_clause",
  with_check as "WITH_CHECK_clause"
FROM pg_policies
WHERE tablename = 'receiving_records';

-- ============================================================================
-- TEST NOW:
-- Try to INSERT a receiving record
-- It should work because the policy is: USING (true) WITH CHECK (true)
-- 
-- This proves the issue is the authentication check (auth.uid() IS NOT NULL)
-- ============================================================================

-- If this works, the fix is:
-- 1. Migrate to Supabase Auth (proper solution)
-- 2. OR implement a custom auth token in JWT for Supabase to recognize
-- 3. OR continue using allow_all_operations for development
--
-- ============================================================================
