-- Find and display database functions that might reference payment_status
-- Run this to see which functions need to be fixed

SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND (
    p.proname LIKE '%clearance%'
    OR p.proname LIKE '%receiving%'
    OR p.proname LIKE '%vendor_payment%'
    OR p.proname LIKE '%payment_schedule%'
)
AND pg_get_functiondef(p.oid) LIKE '%payment_status%'
ORDER BY p.proname;
