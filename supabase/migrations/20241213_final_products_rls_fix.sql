-- FINAL FIX: Ensure RLS is enabled AND policies allow all operations
-- Date: 2024-12-13

-- =============================================================================
-- STEP 1: Enable RLS on products table (if not already enabled)
-- =============================================================================

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    RAISE NOTICE 'Ensured RLS is ENABLED on products table';
END $$;

-- =============================================================================
-- STEP 2: Drop ALL existing policies (clean slate)
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
-- STEP 3: Create SINGLE permissive policy for each operation
-- Using role() = 'authenticated' to match Supabase default
-- =============================================================================

-- SELECT: Allow all authenticated reads
CREATE POLICY "allow_select" 
ON products 
FOR SELECT 
USING (true);

-- INSERT: Allow all authenticated inserts  
CREATE POLICY "allow_insert" 
ON products 
FOR INSERT 
WITH CHECK (true);

-- UPDATE: Allow all authenticated updates - THIS IS THE KEY FIX
CREATE POLICY "allow_update" 
ON products 
FOR UPDATE 
USING (true) 
WITH CHECK (true);

-- DELETE: Allow all authenticated deletes
CREATE POLICY "allow_delete" 
ON products 
FOR DELETE 
USING (true);

DO $$
BEGIN
    RAISE NOTICE 'Created 4 permissive policies on products table';
END $$;

-- =============================================================================
-- STEP 4: Verify policies are in place
-- =============================================================================

DO $$
DECLARE
    select_count INTEGER := 0;
    insert_count INTEGER := 0;
    update_count INTEGER := 0;
    delete_count INTEGER := 0;
BEGIN
    SELECT COUNT(*) INTO select_count FROM pg_policies WHERE tablename = 'products' AND cmd = 'SELECT';
    SELECT COUNT(*) INTO insert_count FROM pg_policies WHERE tablename = 'products' AND cmd = 'INSERT';
    SELECT COUNT(*) INTO update_count FROM pg_policies WHERE tablename = 'products' AND cmd = 'UPDATE';
    SELECT COUNT(*) INTO delete_count FROM pg_policies WHERE tablename = 'products' AND cmd = 'DELETE';
    
    RAISE NOTICE '';
    RAISE NOTICE 'Policy verification:';
    RAISE NOTICE 'SELECT policies: %', select_count;
    RAISE NOTICE 'INSERT policies: %', insert_count;
    RAISE NOTICE 'UPDATE policies: %', update_count;
    RAISE NOTICE 'DELETE policies: %', delete_count;
    
    IF select_count > 0 AND insert_count > 0 AND update_count > 0 AND delete_count > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE 'SUCCESS: All CRUD operations should now be allowed!';
    ELSE
        RAISE WARNING 'ISSUE: Some operations are missing policies';
    END IF;
END $$;

-- =============================================================================
-- STEP 5: Show final policy list
-- =============================================================================

SELECT 
    policyname,
    cmd,
    qual as using_clause,
    with_check as check_clause
FROM pg_policies
WHERE tablename = 'products'
ORDER BY cmd, policyname;
