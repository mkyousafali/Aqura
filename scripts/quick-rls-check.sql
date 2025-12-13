-- ============================================================================
-- QUICK RLS CHECK: Offers vs Products Table
-- Copy and run this in Supabase SQL Editor for instant comparison
-- ============================================================================

-- Quick Status Check
SELECT 
    tablename,
    rowsecurity as "RLS Enabled",
    (SELECT COUNT(*) FROM pg_policies WHERE pg_policies.tablename = pg_tables.tablename) as "# Policies"
FROM pg_tables 
WHERE tablename IN ('offers', 'products')
ORDER BY tablename;

-- Policies on Each Table
RAISE NOTICE '';
RAISE NOTICE '📋 OFFERS Table Policies:';
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'offers' ORDER BY cmd;

RAISE NOTICE '';
RAISE NOTICE '📋 PRODUCTS Table Policies:';
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'products' ORDER BY cmd;
