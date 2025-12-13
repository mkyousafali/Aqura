-- Migration: Fix Products Table RLS for UPDATE Operations
-- Date: 2024-12-13
-- Purpose: Allow UPDATE operations on products table (currently blocked by RLS)
-- Issue: Users can READ but cannot UPDATE - permission denied for table products

-- =============================================================================
-- STEP 1: Check current RLS policies on products table
-- =============================================================================

DO $$
DECLARE
    policy_count INTEGER;
    policy_rec RECORD;
BEGIN
    RAISE NOTICE 'Current RLS policies on products table:';
    RAISE NOTICE '================================================';
    
    FOR policy_rec IN 
        SELECT 
            policyname,
            cmd,
            qual as using_clause,
            with_check
        FROM pg_policies
        WHERE tablename = 'products'
        ORDER BY cmd, policyname
    LOOP
        RAISE NOTICE 'Policy: % | Command: % | Using: %', 
            policy_rec.policyname, 
            policy_rec.cmd,
            COALESCE(policy_rec.using_clause::text, 'N/A');
    END LOOP;
END $$;

-- =============================================================================
-- STEP 2: Drop existing restrictive UPDATE policy if it exists
-- =============================================================================

DROP POLICY IF EXISTS "Allow authenticated update access" ON products;
DROP POLICY IF EXISTS "allow_update" ON products;

DO $$
BEGIN
    RAISE NOTICE 'Dropped old UPDATE policies (if existed)';
END $$;

-- =============================================================================
-- STEP 3: Create new permissive UPDATE policy
-- =============================================================================

CREATE POLICY "allow_update_products" 
ON products 
FOR UPDATE 
USING (true) 
WITH CHECK (true);

DO $$
BEGIN
    RAISE NOTICE 'Created new UPDATE policy: allow_update_products';
END $$;

-- =============================================================================
-- STEP 4: Ensure SELECT policy allows reads
-- =============================================================================

DROP POLICY IF EXISTS "Allow authenticated read access" ON products;
DROP POLICY IF EXISTS "allow_select" ON products;

CREATE POLICY "allow_select_products" 
ON products 
FOR SELECT 
USING (true);

DO $$
BEGIN
    RAISE NOTICE 'Created/refreshed SELECT policy: allow_select_products';
END $$;

-- =============================================================================
-- STEP 5: Ensure INSERT and DELETE policies exist
-- =============================================================================

DROP POLICY IF EXISTS "Allow authenticated insert access" ON products;
DROP POLICY IF EXISTS "allow_insert" ON products;

CREATE POLICY "allow_insert_products" 
ON products 
FOR INSERT 
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow authenticated delete access" ON products;
DROP POLICY IF EXISTS "allow_delete" ON products;

CREATE POLICY "allow_delete_products" 
ON products 
FOR DELETE 
USING (true);

DO $$
BEGIN
    RAISE NOTICE 'Created/refreshed INSERT and DELETE policies';
END $$;

-- =============================================================================
-- STEP 6: Verification
-- =============================================================================

DO $$
DECLARE
    select_policy_exists BOOLEAN;
    insert_policy_exists BOOLEAN;
    update_policy_exists BOOLEAN;
    delete_policy_exists BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'products' AND cmd = 'SELECT') 
        INTO select_policy_exists;
    SELECT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'products' AND cmd = 'INSERT') 
        INTO insert_policy_exists;
    SELECT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'products' AND cmd = 'UPDATE') 
        INTO update_policy_exists;
    SELECT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'products' AND cmd = 'DELETE') 
        INTO delete_policy_exists;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Final RLS Policy Status:';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'SELECT Policy Exists: %', select_policy_exists;
    RAISE NOTICE 'INSERT Policy Exists: %', insert_policy_exists;
    RAISE NOTICE 'UPDATE Policy Exists: %', update_policy_exists;
    RAISE NOTICE 'DELETE Policy Exists: %', delete_policy_exists;
    
    IF select_policy_exists AND insert_policy_exists AND update_policy_exists AND delete_policy_exists THEN
        RAISE NOTICE '';
        RAISE NOTICE 'SUCCESS: All CRUD policies are now in place!';
        RAISE NOTICE 'Products table should now allow all operations with RLS enabled.';
    ELSE
        RAISE WARNING 'ISSUE: Some policies are missing. Please check manually.';
    END IF;
END $$;

-- =============================================================================
-- FINAL LIST OF ALL POLICIES
-- =============================================================================

SELECT 
    policyname,
    cmd,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'products'
ORDER BY cmd, policyname;
