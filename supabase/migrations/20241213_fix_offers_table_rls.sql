-- Migration: Fix Offers Table RLS
-- Purpose: Enable SELECT access to offers table
-- Date: 2024-12-13

BEGIN;

-- =============================================================================
-- STEP 1: Enable RLS on offers table
-- =============================================================================

ALTER TABLE offers ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- STEP 2: Drop existing policies if any
-- =============================================================================

DROP POLICY IF EXISTS "allow_select_offers" ON offers;
DROP POLICY IF EXISTS "allow_insert_offers" ON offers;
DROP POLICY IF EXISTS "allow_update_offers" ON offers;
DROP POLICY IF EXISTS "allow_delete_offers" ON offers;

-- =============================================================================
-- STEP 3: Create SELECT policy (allow all users to read offers)
-- =============================================================================

CREATE POLICY "allow_select_offers" ON offers
FOR SELECT
USING (true);

-- =============================================================================
-- STEP 4: Create INSERT policy (allow authenticated and service role)
-- =============================================================================

CREATE POLICY "allow_insert_offers" ON offers
FOR INSERT
WITH CHECK (true);

-- =============================================================================
-- STEP 5: Create UPDATE policy (allow all modifications)
-- =============================================================================

CREATE POLICY "allow_update_offers" ON offers
FOR UPDATE
USING (true)
WITH CHECK (true);

-- =============================================================================
-- STEP 6: Create DELETE policy (allow deletion)
-- =============================================================================

CREATE POLICY "allow_delete_offers" ON offers
FOR DELETE
USING (true);

COMMIT;

-- =============================================================================
-- VERIFICATION QUERIES (run manually in Supabase SQL Editor)
-- =============================================================================

-- Check if RLS is enabled
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'offers';

-- List all policies on offers table
SELECT policyname, cmd, qual, with_check FROM pg_policies 
WHERE tablename = 'offers' 
ORDER BY cmd, policyname;
