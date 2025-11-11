-- ============================================================
-- GET check_accountant_dependency FUNCTION
-- This is the function that's blocking the accountant!
-- ============================================================

SELECT pg_get_functiondef(oid) as function_definition
FROM pg_proc 
WHERE proname = 'check_accountant_dependency' 
AND pronamespace = 'public'::regnamespace;

-- ============================================================
-- Run this and paste the result back to me
-- ============================================================
