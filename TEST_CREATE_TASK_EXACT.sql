-- Test the create_task function directly to see exact signature
-- First, let's see what the function actually expects

-- Test 1: Check function signature
SELECT 
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as result_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'create_task' AND n.nspname = 'public';

-- Test 2: Try calling create_task with exact parameter count (22 parameters)
DO $$
DECLARE
    test_task_id UUID;
BEGIN
    SELECT create_task(
        'Test Task'::TEXT,                          -- 1. title_param TEXT
        'Test Description'::TEXT,                   -- 2. description_param TEXT
        'user123'::TEXT,                           -- 3. created_by_param TEXT
        'Test User'::TEXT,                         -- 4. created_by_name_param TEXT
        'admin'::TEXT,                             -- 5. created_by_role_param TEXT
        'medium'::TEXT,                            -- 6. priority_param TEXT
        'test'::VARCHAR,                           -- 7. category_param VARCHAR
        CURRENT_DATE::DATE,                        -- 8. due_date_param DATE
        CURRENT_TIME::TIME,                        -- 9. due_time_param TIME
        false::BOOLEAN,                            -- 10. require_task_finished_param BOOLEAN
        false::BOOLEAN,                            -- 11. require_photo_upload_param BOOLEAN
        false::BOOLEAN,                            -- 12. require_erp_reference_param BOOLEAN
        false::BOOLEAN,                            -- 13. can_escalate_param BOOLEAN
        false::BOOLEAN,                            -- 14. can_reassign_param BOOLEAN
        NULL::INTERVAL,                            -- 15. estimated_duration_param INTERVAL
        NULL::BIGINT,                              -- 16. department_id_param BIGINT
        1::BIGINT,                                 -- 17. branch_id_param BIGINT
        NULL::UUID,                                -- 18. project_id_param UUID
        NULL::UUID,                                -- 19. parent_task_id_param UUID
        ARRAY['test']::TEXT[],                     -- 20. tags_param TEXT[]
        '{}'::JSONB,                               -- 21. metadata_param JSONB
        false::BOOLEAN                             -- 22. approval_required_param BOOLEAN
    ) INTO test_task_id;
    
    RAISE NOTICE 'SUCCESS: Task created with ID: %', test_task_id;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR: %', SQLERRM;
END $$;