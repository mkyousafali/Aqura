-- ============================================================================
-- Script: Clean Up Duplicate Offers RLS Policies
-- Purpose: Remove duplicate/conflicting policies and keep clean 4-policy set
-- ============================================================================

BEGIN;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'CLEANUP: Removing Duplicate Offers Policies';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Step 1: Dropping all 9 existing policies...';
END $$;

-- Drop ALL existing policies (including the ones currently on the table)
DROP POLICY IF EXISTS "allow_all_operations" ON offers;
DROP POLICY IF EXISTS "anon_full_access" ON offers;
DROP POLICY IF EXISTS "authenticated_full_access" ON offers;
DROP POLICY IF EXISTS "allow_delete" ON offers;
DROP POLICY IF EXISTS "Allow anon insert offers" ON offers;
DROP POLICY IF EXISTS "allow_insert" ON offers;
DROP POLICY IF EXISTS "allow_select" ON offers;
DROP POLICY IF EXISTS "customer_view_active_offers" ON offers;
DROP POLICY IF EXISTS "allow_update" ON offers;
DROP POLICY IF EXISTS "allow_select_offers" ON offers;
DROP POLICY IF EXISTS "allow_insert_offers" ON offers;
DROP POLICY IF EXISTS "allow_update_offers" ON offers;
DROP POLICY IF EXISTS "allow_delete_offers" ON offers;
DROP POLICY IF EXISTS "rls_select" ON offers;
DROP POLICY IF EXISTS "rls_insert" ON offers;
DROP POLICY IF EXISTS "rls_update" ON offers;
DROP POLICY IF EXISTS "rls_delete" ON offers;
DROP POLICY IF EXISTS "select_offers" ON offers;
DROP POLICY IF EXISTS "insert_offers" ON offers;
DROP POLICY IF EXISTS "update_offers" ON offers;
DROP POLICY IF EXISTS "delete_offers" ON offers;

DO $$
BEGIN
    RAISE NOTICE '✓ Dropped all existing policies';
    RAISE NOTICE '';
    RAISE NOTICE 'Step 2: Ensuring RLS is enabled...';
END $$;

ALTER TABLE offers ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    RAISE NOTICE '✓ RLS enabled on offers table';
    RAISE NOTICE '';
    RAISE NOTICE 'Step 3: Creating clean 4-policy set...';
END $$;

-- SELECT: Allow all users to read
CREATE POLICY "allow_select_offers" ON offers
FOR SELECT
USING (true);

-- INSERT: Allow all users to create
CREATE POLICY "allow_insert_offers" ON offers
FOR INSERT
WITH CHECK (true);

-- UPDATE: Allow all users to edit
CREATE POLICY "allow_update_offers" ON offers
FOR UPDATE
USING (true)
WITH CHECK (true);

-- DELETE: Allow all users to delete
CREATE POLICY "allow_delete_offers" ON offers
FOR DELETE
USING (true);

DO $$
BEGIN
    RAISE NOTICE '✓ Created 4 clean policies (SELECT, INSERT, UPDATE, DELETE)';
    RAISE NOTICE '';
    RAISE NOTICE 'Step 4: Verifying policy count...';
END $$;

-- Verify
DO $$
DECLARE
    total_policies INTEGER;
    select_count INTEGER;
    insert_count INTEGER;
    update_count INTEGER;
    delete_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_policies FROM pg_policies WHERE tablename = 'offers';
    SELECT COUNT(*) INTO select_count FROM pg_policies WHERE tablename = 'offers' AND cmd = 'SELECT';
    SELECT COUNT(*) INTO insert_count FROM pg_policies WHERE tablename = 'offers' AND cmd = 'INSERT';
    SELECT COUNT(*) INTO update_count FROM pg_policies WHERE tablename = 'offers' AND cmd = 'UPDATE';
    SELECT COUNT(*) INTO delete_count FROM pg_policies WHERE tablename = 'offers' AND cmd = 'DELETE';
    
    RAISE NOTICE 'Total policies: %', total_policies;
    RAISE NOTICE '  • SELECT: %', select_count;
    RAISE NOTICE '  • INSERT: %', insert_count;
    RAISE NOTICE '  • UPDATE: %', update_count;
    RAISE NOTICE '  • DELETE: %', delete_count;
    RAISE NOTICE '';
    
    IF total_policies = 4 THEN
        RAISE NOTICE '✓ SUCCESS: Offers table RLS is now clean and optimized!';
    ELSE
        RAISE NOTICE '⚠ WARNING: Expected 4 policies but found %', total_policies;
    END IF;
END $$;

COMMIT;

-- Verify final state
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Final Policy List';
    RAISE NOTICE '====================================================';
END $$;

SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'offers'
ORDER BY cmd, policyname;
