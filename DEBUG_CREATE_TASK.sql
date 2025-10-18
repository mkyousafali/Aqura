-- DEBUG: Let's check the actual create_task function signature
-- Run this in Supabase SQL Editor to see what parameters it actually expects

SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as result_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'create_task' AND n.nspname = 'public';

-- Also let's test a simple function call with minimal parameters
DO $$
DECLARE
    test_task_id UUID;
BEGIN
    -- Test with exact parameter count and types
    SELECT create_task(
        'Test Task',                                -- title_param TEXT
        'Test Description',                         -- description_param TEXT
        'user123',                                  -- created_by_param TEXT
        'Test User',                               -- created_by_name_param TEXT
        'admin',                                   -- created_by_role_param TEXT
        'medium',                                  -- priority_param TEXT
        'test',                                    -- category_param VARCHAR
        CURRENT_DATE,                              -- due_date_param DATE
        CURRENT_TIME,                              -- due_time_param TIME
        false,                                     -- require_task_finished_param BOOLEAN
        false,                                     -- require_photo_upload_param BOOLEAN
        false,                                     -- require_erp_reference_param BOOLEAN
        false,                                     -- can_escalate_param BOOLEAN
        false,                                     -- can_reassign_param BOOLEAN
        NULL::INTERVAL,                            -- estimated_duration_param INTERVAL
        NULL::BIGINT,                              -- department_id_param BIGINT
        1::BIGINT,                                 -- branch_id_param BIGINT
        NULL::UUID,                                -- project_id_param UUID
        NULL::UUID,                                -- parent_task_id_param UUID
        ARRAY['test'],                             -- tags_param TEXT[]
        '{}',                                      -- metadata_param JSONB
        false                                      -- approval_required_param BOOLEAN
    ) INTO test_task_id;
    
    RAISE NOTICE 'SUCCESS: Test task created with ID: %', test_task_id;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR: %', SQLERRM;
END $$;