-- Migration: Align Products Table RLS Policies with Branches Table
-- Date: 2024-12-13
-- Purpose: Match branches table RLS structure (remove duplicates, use consistent naming)
-- Note: Branches has both allow_* and rls_* policies, we'll keep the allow_* for consistency

-- =============================================================================
-- STEP 1: Check current products table policies
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Current products table policies:';
    RAISE NOTICE '================================================';
END $$;

SELECT 
    policyname,
    cmd,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'products'
ORDER BY cmd, policyname;

-- =============================================================================
-- STEP 2: Drop all existing policies on products table
-- =============================================================================

DROP POLICY IF EXISTS "allow_delete_products" ON products;
DROP POLICY IF EXISTS "allow_insert_products" ON products;
DROP POLICY IF EXISTS "allow_select_products" ON products;
DROP POLICY IF EXISTS "allow_update_products" ON products;
DROP POLICY IF EXISTS "allow_delete" ON products;
DROP POLICY IF EXISTS "allow_insert" ON products;
DROP POLICY IF EXISTS "allow_select" ON products;
DROP POLICY IF EXISTS "allow_update" ON products;
DROP POLICY IF EXISTS "rls_delete" ON products;
DROP POLICY IF EXISTS "rls_insert" ON products;
DROP POLICY IF EXISTS "rls_select" ON products;
DROP POLICY IF EXISTS "rls_update" ON products;
DROP POLICY IF EXISTS "Allow authenticated delete access" ON products;
DROP POLICY IF EXISTS "Allow authenticated insert access" ON products;
DROP POLICY IF EXISTS "Allow authenticated read access" ON products;
DROP POLICY IF EXISTS "Allow authenticated update access" ON products;

DO $$
BEGIN
    RAISE NOTICE 'Dropped all existing policies';
END $$;

-- =============================================================================
-- STEP 3: Create policies matching branches table structure
-- =============================================================================

-- SELECT: allow_select (branches uses: USING true)
CREATE POLICY "allow_select" 
ON products 
FOR SELECT 
USING (true);

-- INSERT: allow_insert (branches uses: WITH CHECK true)
CREATE POLICY "allow_insert" 
ON products 
FOR INSERT 
WITH CHECK (true);

-- UPDATE: allow_update (branches uses: USING true WITH CHECK true)
CREATE POLICY "allow_update" 
ON products 
FOR UPDATE 
USING (true) 
WITH CHECK (true);

-- DELETE: allow_delete (branches uses: USING true)
CREATE POLICY "allow_delete" 
ON products 
FOR DELETE 
USING (true);

-- Also create rls_* policies to match branches table exactly
-- SELECT: rls_select (branches uses: USING true)
CREATE POLICY "rls_select" 
ON products 
FOR SELECT 
USING (true);

-- INSERT: rls_insert (branches uses: WITH CHECK true)
CREATE POLICY "rls_insert" 
ON products 
FOR INSERT 
WITH CHECK (true);

-- UPDATE: rls_update (branches uses: WITH CHECK true - note: no USING clause in branches)
CREATE POLICY "rls_update" 
ON products 
FOR UPDATE 
WITH CHECK (true);

-- DELETE: rls_delete (branches uses: USING true)
CREATE POLICY "rls_delete" 
ON products 
FOR DELETE 
USING (true);

DO $$
BEGIN
    RAISE NOTICE 'Created all 8 policies (allow_* and rls_*)';
END $$;

-- =============================================================================
-- STEP 4: Verification
-- =============================================================================

DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count 
    FROM pg_policies 
    WHERE tablename = 'products';
    
    RAISE NOTICE '';
    RAISE NOTICE 'Final verification:';
    RAISE NOTICE '================================================';
    RAISE NOTICE 'Total policies on products table: %', policy_count;
    
    IF policy_count = 8 THEN
        RAISE NOTICE 'SUCCESS: Products table now matches branches table structure!';
    ELSE
        RAISE WARNING 'Expected 8 policies, found %', policy_count;
    END IF;
END $$;

-- =============================================================================
-- STEP 5: Compare products vs branches
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Products table policies:';
    RAISE NOTICE '================================================';
END $$;

SELECT 
    policyname,
    cmd,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'products'
ORDER BY cmd, policyname;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Branches table policies (for comparison):';
    RAISE NOTICE '================================================';
END $$;

SELECT 
    policyname,
    cmd,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'branches'
ORDER BY cmd, policyname;
