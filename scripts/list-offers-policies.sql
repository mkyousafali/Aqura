-- ============================================================================
-- Script: List All Policies on Offers Table
-- Purpose: See exactly what the 9 policies are
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'All 9 Policies on Offers Table';
    RAISE NOTICE '====================================================';
END $$;

SELECT 
    policyname as "Policy Name",
    cmd as "Operation",
    CASE 
        WHEN cmd = 'SELECT' THEN 'READ'
        WHEN cmd = 'INSERT' THEN 'CREATE'
        WHEN cmd = 'UPDATE' THEN 'EDIT'
        WHEN cmd = 'DELETE' THEN 'DELETE'
    END as "Type",
    qual as "USING Clause",
    with_check as "WITH CHECK Clause"
FROM pg_policies 
WHERE tablename = 'offers'
ORDER BY cmd, policyname;

DO $$
DECLARE
    count_select INTEGER;
    count_insert INTEGER;
    count_update INTEGER;
    count_delete INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Policy Count by Operation Type';
    RAISE NOTICE '====================================================';
    
    SELECT COUNT(*) INTO count_select FROM pg_policies WHERE tablename = 'offers' AND cmd = 'SELECT';
    SELECT COUNT(*) INTO count_insert FROM pg_policies WHERE tablename = 'offers' AND cmd = 'INSERT';
    SELECT COUNT(*) INTO count_update FROM pg_policies WHERE tablename = 'offers' AND cmd = 'UPDATE';
    SELECT COUNT(*) INTO count_delete FROM pg_policies WHERE tablename = 'offers' AND cmd = 'DELETE';
    
    RAISE NOTICE 'SELECT: % policies', count_select;
    RAISE NOTICE 'INSERT: % policies', count_insert;
    RAISE NOTICE 'UPDATE: % policies', count_update;
    RAISE NOTICE 'DELETE: % policies', count_delete;
    RAISE NOTICE '';
    RAISE NOTICE 'TOTAL: % policies', (count_select + count_insert + count_update + count_delete);
    RAISE NOTICE '';
    
    IF count_select > 1 OR count_insert > 1 OR count_update > 1 OR count_delete > 1 THEN
        RAISE NOTICE 'WARNING: Multiple policies per operation type detected!';
        RAISE NOTICE 'Consider running cleanup script to consolidate policies.';
    ELSE
        RAISE NOTICE '✓ Clean policy structure (one policy per operation)';
    END IF;
END $$;
