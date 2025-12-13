-- OPTION 1: Disable RLS on products table entirely
-- Use this if RLS is causing 401 errors and you want open access

ALTER TABLE products DISABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    RAISE NOTICE 'SUCCESS: RLS disabled on products table';
    RAISE NOTICE 'Products table is now accessible without RLS restrictions';
END $$;

-- Verify RLS is disabled
SELECT 
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'products';
