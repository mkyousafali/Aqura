-- ULTRA SIMPLE FIX: Minimal function with exact typing and error handling
-- This removes all potential issues and focuses on the core problem

CREATE OR REPLACE FUNCTION generate_clearance_certificate_tasks(
    receiving_record_id_param UUID,
    clearance_certificate_url_param TEXT,
    created_by_user_id TEXT,
    created_by_name TEXT DEFAULT NULL,
    created_by_role TEXT DEFAULT NULL
)
RETURNS TABLE(
    task_count INTEGER,
    notification_count INTEGER,
    task_ids UUID[],
    assignment_ids UUID[]
) AS $$
DECLARE
    receiving_record RECORD;
    task_id UUID;
    deadline_datetime TIMESTAMPTZ;
BEGIN
    deadline_datetime := now() + INTERVAL '24 hours';
    
    -- Get receiving record details
    SELECT * INTO receiving_record 
    FROM receiving_records 
    WHERE id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving record not found: %', receiving_record_id_param;
    END IF;
    
    -- Create ONLY inventory manager task (NO ERP requirement)
    IF receiving_record.inventory_manager_user_id IS NOT NULL THEN
        -- Call create_task with explicit types for all parameters
        task_id := create_task(
            'New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill',  -- title_param
            'Simple delivery task description',                                          -- description_param  
            created_by_user_id,                                                         -- created_by_param
            COALESCE(created_by_name, ''),                                             -- created_by_name_param
            COALESCE(created_by_role, ''),                                             -- created_by_role_param
            'high',                                                                     -- priority_param
            'receiving_delivery',                                                       -- category_param
            deadline_datetime::DATE,                                                    -- due_date_param
            deadline_datetime::TIME,                                                    -- due_time_param  
            true,                                                                       -- require_task_finished_param
            false,                                                                      -- require_photo_upload_param
            false,                                                                      -- require_erp_reference_param (NO ERP!)
            false,                                                                      -- can_escalate_param
            false,                                                                      -- can_reassign_param
            NULL,                                                                       -- estimated_duration_param
            NULL,                                                                       -- department_id_param
            receiving_record.branch_id,                                                 -- branch_id_param (SINGLE VALUE!)
            NULL,                                                                       -- project_id_param
            NULL,                                                                       -- parent_task_id_param
            ARRAY['delivery'],                                                          -- tags_param
            '{}',                                                                       -- metadata_param (simple empty object)
            false                                                                       -- approval_required_param
        );
        
        RAISE NOTICE 'Task created successfully with ID: %', task_id;
        
        RETURN QUERY SELECT 1, 0, ARRAY[task_id], ARRAY[]::UUID[];
    ELSE
        RAISE NOTICE 'No inventory manager assigned to receiving record';
        RETURN QUERY SELECT 0, 0, ARRAY[]::UUID[], ARRAY[]::UUID[];
    END IF;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in generate_clearance_certificate_tasks: %', SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql;