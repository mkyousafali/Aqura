-- Fix RLS policy on system_api_keys to use correct Supabase roles
-- The problem: Policy was set to {public} role, but Supabase clients use {anon} and {authenticated}

-- Drop the incorrect policy
DROP POLICY IF EXISTS "Allow all access to system_api_keys" ON public.system_api_keys;

-- Create correct policy that applies to all Supabase roles
CREATE POLICY "Allow all access to system_api_keys"
  ON public.system_api_keys
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Verify the policy was created correctly
SELECT policyname, permissive, roles FROM pg_policies WHERE tablename = 'system_api_keys';
