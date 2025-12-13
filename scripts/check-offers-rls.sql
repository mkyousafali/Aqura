-- ============================================================================
-- SCRIPT: Check and Verify RLS on Offers Table
-- Purpose: Diagnostic script to verify RLS configuration on offers table
-- Usage: Run in Supabase SQL Editor to check current RLS status
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'STEP 1: RLS Status on Offers Table';
    RAISE NOTICE '====================================================';
END $$;

SELECT 
    tablename,
    rowsecurity as "RLS Enabled?"
FROM pg_tables 
WHERE tablename = 'offers'
ORDER BY tablename;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'STEP 2: Current Policies on Offers Table';
    RAISE NOTICE '====================================================';
END $$;

SELECT 
    policyname as "Policy Name",
    cmd as "Operation",
    qual as "USING Clause (Read/Delete)",
    with_check as "WITH CHECK Clause (Write/Update)"
FROM pg_policies 
WHERE tablename = 'offers'
ORDER BY cmd, policyname;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'STEP 3: Policy Count by Operation';
    RAISE NOTICE '====================================================';
END $$;

SELECT 
    COALESCE(cmd, 'NONE') as "Operation",
    COUNT(*) as "Count"
FROM pg_policies 
WHERE tablename = 'offers'
GROUP BY cmd
UNION ALL
SELECT 
    'TOTAL' as "Operation",
    COUNT(*) as "Count"
FROM pg_policies 
WHERE tablename = 'offers'
ORDER BY "Count" DESC;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'STEP 4: Table Privileges and Grants';
    RAISE NOTICE '====================================================';
END $$;

SELECT 
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.role_table_grants 
WHERE table_name = 'offers'
ORDER BY grantee, privilege_type;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'STEP 5: Comparison - Offers vs Products Table';
    RAISE NOTICE '====================================================';
END $$;

SELECT 
    'offers' as "Table",
    COUNT(*) as "Policy Count"
FROM pg_policies 
WHERE tablename = 'offers'
UNION ALL
SELECT 
    'products' as "Table",
    COUNT(*) as "Policy Count"
FROM pg_policies 
WHERE tablename = 'products';

DO $$
DECLARE
    select_count INTEGER := 0;
    insert_count INTEGER := 0;
    update_count INTEGER := 0;
    delete_count INTEGER := 0;
    rls_enabled BOOLEAN := false;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'STEP 6: Detailed Policy Analysis';
    RAISE NOTICE '====================================================';
    
    -- Check RLS status
    SELECT rowsecurity INTO rls_enabled FROM pg_tables WHERE tablename = 'offers';
    
    -- Count policies by type
    SELECT COUNT(*) INTO select_count FROM pg_policies WHERE tablename = 'offers' AND cmd = 'SELECT';
    SELECT COUNT(*) INTO insert_count FROM pg_policies WHERE tablename = 'offers' AND cmd = 'INSERT';
    SELECT COUNT(*) INTO update_count FROM pg_policies WHERE tablename = 'offers' AND cmd = 'UPDATE';
    SELECT COUNT(*) INTO delete_count FROM pg_policies WHERE tablename = 'offers' AND cmd = 'DELETE';
    
    RAISE NOTICE '';
    RAISE NOTICE 'RLS Status:';
    RAISE NOTICE '  • RLS Enabled: %', rls_enabled;
    RAISE NOTICE '';
    RAISE NOTICE 'CRUD Operation Policies:';
    RAISE NOTICE '  • SELECT policies: % %', select_count, CASE WHEN select_count > 0 THEN '✓' ELSE '✗ MISSING' END;
    RAISE NOTICE '  • INSERT policies: % %', insert_count, CASE WHEN insert_count > 0 THEN '✓' ELSE '✗ MISSING' END;
    RAISE NOTICE '  • UPDATE policies: % %', update_count, CASE WHEN update_count > 0 THEN '✓' ELSE '✗ MISSING' END;
    RAISE NOTICE '  • DELETE policies: % %', delete_count, CASE WHEN delete_count > 0 THEN '✓' ELSE '✗ MISSING' END;
    RAISE NOTICE '';
    
    IF rls_enabled AND select_count > 0 AND insert_count > 0 AND update_count > 0 AND delete_count > 0 THEN
        RAISE NOTICE 'STATUS: ✓ Offers table RLS is properly configured!';
    ELSIF NOT rls_enabled THEN
        RAISE NOTICE 'STATUS: ✗ RLS is DISABLED on offers table';
        RAISE NOTICE 'FIX: Run the offers RLS migration to enable RLS and create policies';
    ELSE
        RAISE NOTICE 'STATUS: ⚠ Offers table has RLS enabled but some policies are MISSING';
        RAISE NOTICE 'FIX: Run the offers RLS migration to add missing policies';
    END IF;
END $$;

DO $$
DECLARE
    offer_count INTEGER := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'STEP 7: Test SELECT Query';
    RAISE NOTICE '====================================================';
    
    SELECT COUNT(*) INTO offer_count FROM offers;
    RAISE NOTICE 'Successfully selected % offers from table', offer_count;
    RAISE NOTICE 'SELECT permission: ✓ Working';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SELECT permission: ✗ Failed - %', SQLERRM;
END $$;

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'SUMMARY & NEXT STEPS';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'If offers table RLS is MISSING policies:';
    RAISE NOTICE '  1. Open: supabase/migrations/20241213_fix_offers_table_rls.sql';
    RAISE NOTICE '  2. Copy all SQL code from that file';
    RAISE NOTICE '  3. Paste into Supabase SQL Editor → New Query';
    RAISE NOTICE '  4. Click "Run" button';
    RAISE NOTICE '  5. Re-run this diagnostic script to verify';
    RAISE NOTICE '';
END $$;
