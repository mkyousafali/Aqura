-- Test SQL to verify create_task function signature
-- Run this in Supabase SQL Editor to check current function

SELECT 
    routine_name,
    parameter_name,
    data_type,
    ordinal_position
FROM information_schema.parameters 
WHERE specific_name LIKE '%create_task%'
ORDER BY ordinal_position;

-- Test a simple create_task call with explicit types
DO $$
DECLARE
    test_task_id UUID;
BEGIN
    SELECT create_task(
        'Test Task'::TEXT,
        'Test Description'::TEXT,
        'user123'::TEXT,
        'Test User'::TEXT,
        'admin'::TEXT,
        'high'::TEXT,
        'test'::VARCHAR,
        '2024-10-18'::DATE,
        '10:00:00'::TIME,
        true::BOOLEAN,
        false::BOOLEAN,
        false::BOOLEAN,
        false::BOOLEAN,
        false::BOOLEAN,
        NULL::INTERVAL,
        NULL::BIGINT,
        1::BIGINT,
        NULL::UUID,
        NULL::UUID,
        ARRAY['test']::TEXT[],
        '{}'::JSONB,
        false::BOOLEAN
    ) INTO test_task_id;
    
    RAISE NOTICE 'Test task created with ID: %', test_task_id;
    
    -- Clean up test
    DELETE FROM tasks WHERE id = test_task_id;
END $$;