-- CRITICAL FIX: Grant table permissions to anon role
-- The 401 error indicates the anon role doesn't have table-level grants
-- Date: 2024-12-13

-- =============================================================================
-- STEP 1: Ensure RLS is enabled
-- =============================================================================

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    RAISE NOTICE 'RLS is ENABLED on products table';
END $$;

-- =============================================================================
-- STEP 2: Grant table-level permissions to anon role
-- This is required even with permissive RLS policies
-- =============================================================================

GRANT SELECT ON products TO anon;
GRANT INSERT ON products TO anon;
GRANT UPDATE ON products TO anon;
GRANT DELETE ON products TO anon;

DO $$
BEGIN
    RAISE NOTICE 'Granted SELECT, INSERT, UPDATE, DELETE to anon role';
END $$;

-- =============================================================================
-- STEP 3: Also grant to authenticated role (for any authenticated users)
-- =============================================================================

GRANT SELECT ON products TO authenticated;
GRANT INSERT ON products TO authenticated;
GRANT UPDATE ON products TO authenticated;
GRANT DELETE ON products TO authenticated;

DO $$
BEGIN
    RAISE NOTICE 'Granted SELECT, INSERT, UPDATE, DELETE to authenticated role';
END $$;

-- =============================================================================
-- STEP 4: Drop all existing policies
-- =============================================================================

DO $$
DECLARE
    policy_rec RECORD;
BEGIN
    FOR policy_rec IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'products'
    LOOP
        EXECUTE 'DROP POLICY IF EXISTS "' || policy_rec.policyname || '" ON products';
        RAISE NOTICE 'Dropped policy: %', policy_rec.policyname;
    END LOOP;
END $$;

-- =============================================================================
-- STEP 5: Create permissive policies for all roles (anon + authenticated)
-- =============================================================================

-- SELECT: Allow all users
CREATE POLICY "allow_select_all" 
ON products 
FOR SELECT 
USING (true);

-- INSERT: Allow all users
CREATE POLICY "allow_insert_all" 
ON products 
FOR INSERT 
WITH CHECK (true);

-- UPDATE: Allow all users - THIS FIXES THE 401 ERROR
CREATE POLICY "allow_update_all" 
ON products 
FOR UPDATE 
USING (true) 
WITH CHECK (true);

-- DELETE: Allow all users
CREATE POLICY "allow_delete_all" 
ON products 
FOR DELETE 
USING (true);

DO $$
BEGIN
    RAISE NOTICE 'Created 4 permissive policies';
END $$;

-- =============================================================================
-- STEP 6: Verify grants
-- =============================================================================

DO $$
DECLARE
    grant_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO grant_count 
    FROM information_schema.role_table_grants
    WHERE table_name = 'products' 
    AND grantee IN ('anon', 'authenticated');
    
    RAISE NOTICE '';
    RAISE NOTICE 'Verification:';
    RAISE NOTICE 'Total grants on products table: %', grant_count;
    
    IF grant_count >= 8 THEN
        RAISE NOTICE 'SUCCESS: anon and authenticated roles have full permissions!';
    ELSE
        RAISE WARNING 'WARNING: Expected at least 8 grants, found %', grant_count;
    END IF;
END $$;

-- =============================================================================
-- STEP 7: Show current state
-- =============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Current RLS policies:';
    RAISE NOTICE '================================================';
END $$;

SELECT 
    policyname,
    cmd,
    qual as using_clause,
    with_check as check_clause
FROM pg_policies
WHERE tablename = 'products'
ORDER BY cmd, policyname;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'Current grants to anon and authenticated:';
    RAISE NOTICE '================================================';
END $$;

SELECT 
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.role_table_grants
WHERE table_name = 'products' 
AND grantee IN ('anon', 'authenticated')
ORDER BY grantee, privilege_type;
