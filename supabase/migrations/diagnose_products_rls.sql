-- Diagnostic: Check RLS Status and Authentication Context
-- This will help identify why UPDATE is still blocked

-- =============================================================================
-- STEP 1: Check if RLS is enabled on products table
-- =============================================================================

SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'products';

-- =============================================================================
-- STEP 2: List all policies on products table with full details
-- =============================================================================

SELECT 
    policyname,
    tablename,
    cmd,
    permissive,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'products'
ORDER BY cmd, policyname;

-- =============================================================================
-- STEP 3: Check authentication status
-- =============================================================================

SELECT 
    current_user as current_user,
    session_user as session_user,
    current_schema as current_schema;

-- =============================================================================
-- STEP 4: Test a simple INSERT (if RLS allows it)
-- =============================================================================

-- This is a diagnostic only - shows what role is being used
DO $$
BEGIN
    RAISE NOTICE 'Current user context: %', current_user;
    RAISE NOTICE 'Session user: %', session_user;
END $$;

-- =============================================================================
-- STEP 5: Check if there are any column-level permissions blocking updates
-- =============================================================================

SELECT 
    grantee,
    privilege_type,
    table_name,
    column_name
FROM information_schema.role_column_grants
WHERE table_name = 'products'
ORDER BY column_name, privilege_type;

-- =============================================================================
-- STEP 6: Check table-level grants
-- =============================================================================

SELECT 
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.role_table_grants
WHERE table_name = 'products'
ORDER BY grantee, privilege_type;
