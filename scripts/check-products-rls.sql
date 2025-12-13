-- Check RLS on products table
DO $$
BEGIN
    RAISE NOTICE 'Checking RLS configuration on products table';
END $$;

SELECT 
    tablename,
    rowsecurity as "RLS Enabled?"
FROM pg_tables 
WHERE tablename = 'products';

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE 'RLS Policies on products table:';
END $$;

SELECT 
    policyname as "Policy Name",
    cmd as "Operation",
    qual as "USING",
    with_check as "WITH CHECK"
FROM pg_policies 
WHERE tablename = 'products'
ORDER BY cmd, policyname;
