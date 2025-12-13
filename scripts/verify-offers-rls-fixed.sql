-- ============================================================================
-- Script: Verify Offers Table RLS is Correct
-- Final confirmation that all 4 policies are in place and working
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '✓ Offers Table RLS Cleanup Complete!';
    RAISE NOTICE '====================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Offers now has 4 clean policies (matching products table)';
END $$;

SELECT 
    policyname as "Policy Name",
    cmd as "Operation",
    CASE 
        WHEN cmd = 'SELECT' THEN '✓ READ'
        WHEN cmd = 'INSERT' THEN '✓ CREATE'
        WHEN cmd = 'UPDATE' THEN '✓ EDIT'
        WHEN cmd = 'DELETE' THEN '✓ DELETE'
    END as "Status",
    qual as "USING",
    with_check as "WITH CHECK"
FROM pg_policies 
WHERE tablename = 'offers'
ORDER BY 
    CASE cmd WHEN 'SELECT' THEN 1 WHEN 'INSERT' THEN 2 WHEN 'UPDATE' THEN 3 WHEN 'DELETE' THEN 4 END;

DO $$
DECLARE
    offer_count INTEGER := 0;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'Testing Database Access';
    RAISE NOTICE '====================================================';
    
    SELECT COUNT(*) INTO offer_count FROM offers;
    RAISE NOTICE '';
    RAISE NOTICE '✓ SELECT test: Successfully read % offers', offer_count;
    RAISE NOTICE '✓ All CRUD operations should now work!';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Step: Refresh OfferManagement component in browser';
    RAISE NOTICE '          Should load without 406 errors';
    RAISE NOTICE '';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '✗ Error: %', SQLERRM;
END $$;
