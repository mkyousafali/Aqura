-- Minimal test of create_task function with exact types
-- This will help us identify the exact issue

DO $$
DECLARE
    test_task_id UUID;
BEGIN
    -- Test with minimal parameters using exact types the function expects
    SELECT create_task(
        'Test Task'::TEXT,                           -- title_param TEXT
        'Test Description'::TEXT,                    -- description_param TEXT  
        'test-user-id'::TEXT,                       -- created_by_param TEXT
        'Test User'::TEXT,                          -- created_by_name_param TEXT
        'admin'::TEXT,                              -- created_by_role_param TEXT
        'medium'::TEXT,                             -- priority_param TEXT
        'test'::VARCHAR,                            -- category_param VARCHAR
        CURRENT_DATE::DATE,                         -- due_date_param DATE
        CURRENT_TIME::TIME,                         -- due_time_param TIME
        false::BOOLEAN,                             -- require_task_finished_param BOOLEAN
        false::BOOLEAN,                             -- require_photo_upload_param BOOLEAN
        false::BOOLEAN,                             -- require_erp_reference_param BOOLEAN
        false::BOOLEAN,                             -- can_escalate_param BOOLEAN
        false::BOOLEAN,                             -- can_reassign_param BOOLEAN
        NULL::INTERVAL,                             -- estimated_duration_param INTERVAL
        NULL::BIGINT,                               -- department_id_param BIGINT
        1::BIGINT,                                  -- branch_id_param BIGINT (test with 1)
        NULL::UUID,                                 -- project_id_param UUID
        NULL::UUID,                                 -- parent_task_id_param UUID
        ARRAY['test']::TEXT[],                      -- tags_param TEXT[]
        '{}'::JSONB,                                -- metadata_param JSONB
        false::BOOLEAN                              -- approval_required_param BOOLEAN
    ) INTO test_task_id;
    
    RAISE NOTICE 'Test task created successfully with ID: %', test_task_id;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error creating test task: %', SQLERRM;
END $$;