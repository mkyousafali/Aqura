-- FIXED CLEANUP: Properly drop ALL create_task functions
-- Use correct syntax for dropping functions

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

-- Drop ALL create_task functions using proper syntax
DO $$
DECLARE
    func_record RECORD;
    drop_sql TEXT;
BEGIN
    FOR func_record IN 
        SELECT 
            p.proname, 
            pg_get_function_identity_arguments(p.oid) as identity_args,
            p.pronamespace::regnamespace as schema_name
        FROM pg_proc p 
        JOIN pg_namespace n ON p.pronamespace = n.oid 
        WHERE n.nspname = 'public' 
        AND p.proname = 'create_task'
    LOOP
        drop_sql := 'DROP FUNCTION IF EXISTS ' || func_record.schema_name || '.' || func_record.proname || '(' || func_record.identity_args || ')';
        RAISE NOTICE 'Executing: %', drop_sql;
        EXECUTE drop_sql;
        RAISE NOTICE 'Dropped function: % with args: %', func_record.proname, func_record.identity_args;
    END LOOP;
END
$$;

-- Verify all create_task functions are gone
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p 
JOIN pg_namespace n ON p.pronamespace = n.oid 
WHERE n.nspname = 'public' 
AND p.proname = 'create_task';