-- Get all function names that reference role_type in their definition

SELECT 
    p.proname as function_name
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND p.prokind = 'f'  -- Only functions, not aggregates
AND pg_get_functiondef(p.oid) ILIKE '%role_type%'
ORDER BY p.proname;
