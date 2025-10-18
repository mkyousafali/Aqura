-- AGGRESSIVE CLEANUP: Find and drop ALL create_task functions
-- This will query the database to find all versions and drop them

-- First, let's see what create_task functions actually exist
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_identity_arguments(p.oid) as identity_args,
    p.oid as function_oid
FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'public' 
AND p.proname = 'create_task';

-- Drop ALL create_task functions by OID (more thorough)
DO $$
DECLARE
    func_record RECORD;
BEGIN
    FOR func_record IN 
        SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args
        FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'public' 
        AND p.proname = 'create_task'
    LOOP
        EXECUTE 'DROP FUNCTION ' || func_record.oid || '()';
        RAISE NOTICE 'Dropped function: % with args: %', func_record.proname, func_record.args;
    END LOOP;
END
$$;