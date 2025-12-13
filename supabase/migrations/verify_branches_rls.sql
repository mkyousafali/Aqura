-- Check Branches Table RLS Policies
-- Compare with products table to ensure consistency

SELECT 
    policyname,
    cmd,
    qual as using_clause,
    with_check
FROM pg_policies
WHERE tablename = 'branches'
ORDER BY cmd, policyname;
