-- Fix RLS policies for customer access to bundle and BOGO offers
-- Run this in Supabase SQL Editor

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "allow_public_read_bundles" ON offer_bundles;
DROP POLICY IF EXISTS "allow_customers_read_bundles" ON offer_bundles;
DROP POLICY IF EXISTS "allow_public_read_bogo" ON bogo_offer_rules;
DROP POLICY IF EXISTS "allow_customers_read_bogo_rules" ON bogo_offer_rules;

-- Create policy for offer_bundles table
-- Allows anonymous and authenticated users to read bundle data
CREATE POLICY "allow_public_read_bundles"
ON offer_bundles
FOR SELECT
TO anon, authenticated
USING (true);

-- Create policy for bogo_offer_rules table  
-- Allows anonymous and authenticated users to read BOGO rules
CREATE POLICY "allow_public_read_bogo"
ON bogo_offer_rules
FOR SELECT
TO anon, authenticated
USING (true);

-- Verify policies were created
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
FROM pg_policies 
WHERE tablename IN ('offer_bundles', 'bogo_offer_rules')
ORDER BY tablename, policyname;
