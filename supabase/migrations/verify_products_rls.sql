-- Verify Products Table RLS Policies
-- Run this to confirm all CRUD policies are in place

SELECT 
    policyname,
    cmd,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'products'
ORDER BY cmd, policyname;
