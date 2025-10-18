-- SIMPLE FIX: Just fix the type casting issue
-- This is the minimal change needed to make the function work

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
    vendor_record RECORD;
    task_id UUID;
    assignment_id UUID;
    deadline_datetime TIMESTAMPTZ;
    task_description TEXT;
    total_tasks INTEGER := 0;
    total_notifications INTEGER := 0;
    created_task_ids UUID[] := '{}';
    created_assignment_ids UUID[] := '{}';
BEGIN
    deadline_datetime := now() + INTERVAL '24 hours';
    
    SELECT * INTO receiving_record FROM receiving_records WHERE id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving record not found: %', receiving_record_id_param;
    END IF;
    
    SELECT * INTO vendor_record FROM vendors WHERE erp_vendor_id = receiving_record.vendor_id;
    
    task_description := format('Vendor: %s, Bill Date: %s, Received by: %s',
        COALESCE(vendor_record.vendor_name, 'Unknown Vendor'),
        receiving_record.bill_date::TEXT,
        COALESCE(created_by_name, 'Unknown User')
    );
    
    -- ONLY INVENTORY MANAGER TASK (simplified)
    IF receiving_record.inventory_manager_user_id IS NOT NULL THEN
        -- Direct task creation with exactly 22 parameters to match create_task function
        SELECT create_task(
            'New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill',  -- 1. title_param
            task_description,                                                             -- 2. description_param
            created_by_user_id,                                                          -- 3. created_by_param
            COALESCE(created_by_name, ''),                                              -- 4. created_by_name_param
            COALESCE(created_by_role, ''),                                              -- 5. created_by_role_param
            'high',                                                                      -- 6. priority_param
            'receiving_delivery',                                                        -- 7. category_param
            deadline_datetime::DATE,                                                     -- 8. due_date_param
            deadline_datetime::TIME,                                                     -- 9. due_time_param
            true,                                                                        -- 10. require_task_finished_param
            false,                                                                       -- 11. require_photo_upload_param
            false,                                                                       -- 12. require_erp_reference_param (NO ERP!)
            false,                                                                       -- 13. can_escalate_param
            false,                                                                       -- 14. can_reassign_param
            NULL::INTERVAL,                                                              -- 15. estimated_duration_param
            NULL::BIGINT,                                                                -- 16. department_id_param
            receiving_record.branch_id::BIGINT,                                          -- 17. branch_id_param
            NULL::UUID,                                                                  -- 18. project_id_param
            NULL::UUID,                                                                  -- 19. parent_task_id_param
            ARRAY['delivery', 'erp_entry', 'original_bill'],                            -- 20. tags_param
            jsonb_build_object(                                                          -- 21. metadata_param
                'receiving_record_id', receiving_record_id_param,
                'role_type', 'inventory_manager',
                'clearance_certificate_url', clearance_certificate_url_param
            ),
            false                                                                        -- 22. approval_required_param
        ) INTO task_id;
        
        RAISE NOTICE 'Task created with ID: %', task_id;
        
        total_tasks := 1;
        created_task_ids := ARRAY[task_id];
    ELSE
        RAISE NOTICE 'No inventory manager assigned to receiving record';
    END IF;
    
    RETURN QUERY SELECT total_tasks, 0, created_task_ids, ARRAY[]::UUID[];
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in function: %', SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql;