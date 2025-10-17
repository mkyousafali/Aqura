-- DIAGNOSTIC: Check what create_task functions exist
-- Run this first to see what's available

-- Check if create_task function exists and what signatures are available
DO $$
DECLARE
    rec RECORD;
BEGIN
    -- Try to find create_task functions
    FOR rec IN 
        SELECT 
            proname as function_name,
            pronargs as arg_count,
            proargtypes::regtype[] as arg_types
        FROM pg_proc 
        WHERE proname = 'create_task'
    LOOP
        RAISE NOTICE 'Found function: % with % args: %', rec.function_name, rec.arg_count, rec.arg_types;
    END LOOP;
    
    -- If no functions found
    IF NOT FOUND THEN
        RAISE NOTICE 'No create_task function found!';
    END IF;
END $$;

-- Alternative: Try a simple test call to see the exact error
DO $$
DECLARE
    test_id UUID;
BEGIN
    -- Try the most basic create_task call
    BEGIN
        test_id := create_task('Test Title');
        RAISE NOTICE 'Basic create_task works, returned: %', test_id;
        -- Clean up
        DELETE FROM tasks WHERE id = test_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Basic create_task failed: %', SQLERRM;
    END;
    
    -- Try with more parameters
    BEGIN
        test_id := create_task(
            'Test Title',
            'Test Description',
            'user123'
        );
        RAISE NOTICE 'create_task with 3 params works, returned: %', test_id;
        -- Clean up
        DELETE FROM tasks WHERE id = test_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'create_task with 3 params failed: %', SQLERRM;
    END;
END $$;