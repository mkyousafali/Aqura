-- FINAL FIX: Direct function call without parameter names
-- This should work because it matches the exact function signature

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
    branch_record RECORD;
    task_id UUID;
    assignment_id UUID;
    receiving_task_id UUID;
    deadline_datetime TIMESTAMPTZ;
    task_description TEXT;
    user_id UUID;
    user_ids UUID[];
    total_tasks INTEGER := 0;
    total_notifications INTEGER := 0;
    created_task_ids UUID[] := '{}';
    created_assignment_ids UUID[] := '{}';
    notification_id UUID;
BEGIN
    -- Set deadline to 24 hours from now
    deadline_datetime := now() + INTERVAL '24 hours';
    
    -- Get receiving record details
    SELECT * INTO receiving_record 
    FROM receiving_records 
    WHERE id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving record not found: %', receiving_record_id_param;
    END IF;
    
    -- Get vendor details
    SELECT * INTO vendor_record 
    FROM vendors 
    WHERE erp_vendor_id = receiving_record.vendor_id;
    
    -- Get branch details
    SELECT * INTO branch_record 
    FROM branches 
    WHERE id = receiving_record.branch_id;
    
    -- Create base task description components
    task_description := format('Vendor: %s, Bill Date: %s, Received by: %s',
        COALESCE(vendor_record.vendor_name, 'Unknown Vendor'),
        receiving_record.bill_date::TEXT,
        COALESCE(created_by_name, 'Unknown User')
    );
    
    -- =============================================
    -- 1. Branch Manager Task (SIMPLIFIED TEST)
    -- =============================================
    IF receiving_record.branch_manager_user_id IS NOT NULL THEN
        -- Create task using exact positional parameters - no names
        task_id := create_task(
            'New Delivery Arrived – Start Placing', -- title_param TEXT
            task_description, -- description_param TEXT
            created_by_user_id, -- created_by_param TEXT  
            COALESCE(created_by_name, ''), -- created_by_name_param TEXT
            COALESCE(created_by_role, ''), -- created_by_role_param TEXT
            'high', -- priority_param TEXT
            'receiving_delivery', -- category_param VARCHAR
            deadline_datetime::DATE, -- due_date_param DATE
            deadline_datetime::TIME, -- due_time_param TIME
            true, -- require_task_finished_param BOOLEAN
            false, -- require_photo_upload_param BOOLEAN
            false, -- require_erp_reference_param BOOLEAN
            false, -- can_escalate_param BOOLEAN
            true, -- can_reassign_param BOOLEAN
            NULL, -- estimated_duration_param INTERVAL
            NULL, -- department_id_param BIGINT
            receiving_record.branch_id, -- branch_id_param BIGINT
            NULL, -- project_id_param UUID
            NULL, -- parent_task_id_param UUID
            ARRAY['delivery', 'branch_management'], -- tags_param TEXT[]
            jsonb_build_object(
                'receiving_record_id', receiving_record_id_param,
                'role_type', 'branch_manager',
                'clearance_certificate_url', clearance_certificate_url_param
            ), -- metadata_param JSONB
            false -- approval_required_param BOOLEAN
        );
        
        -- Assign task
        SELECT assign_task(
            task_id,
            'primary',
            receiving_record.branch_manager_user_id::TEXT,
            NULL,
            created_by_user_id,
            created_by_name,
            NULL, -- schedule_date
            NULL, -- schedule_time
            deadline_datetime::DATE,
            deadline_datetime::TIME,
            'high', -- priority_override
            'Clearance certificate attached',
            false, -- require_photo_upload
            false, -- require_erp_reference
            jsonb_build_object('clearance_certificate_url', clearance_certificate_url_param)
        ) INTO assignment_id;
        
        -- Create receiving task record
        INSERT INTO receiving_tasks (
            receiving_record_id, task_id, assignment_id, role_type,
            assigned_user_id, requires_reassignment, clearance_certificate_url
        ) VALUES (
            receiving_record_id_param, task_id, assignment_id, 'branch_manager',
            receiving_record.branch_manager_user_id, true, clearance_certificate_url_param
        ) RETURNING id INTO receiving_task_id;
        
        total_tasks := total_tasks + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
        
        -- Create notification
        INSERT INTO notifications (
            title, message, created_by, created_by_name, created_by_role,
            target_type, target_users, type, priority,
            task_id, task_assignment_id, has_attachments,
            metadata
        ) VALUES (
            'New Delivery Task Assigned',
            format('You have been assigned a new delivery task: %s', task_description),
            created_by_user_id, created_by_name, created_by_role,
            'specific_users', to_jsonb(ARRAY[receiving_record.branch_manager_user_id::TEXT]),
            'task', 'high', task_id, assignment_id, true,
            jsonb_build_object(
                'receiving_record_id', receiving_record_id_param,
                'clearance_certificate_url', clearance_certificate_url_param
            )
        ) RETURNING id INTO notification_id;
        
        total_notifications := total_notifications + 1;
    END IF;
    
    -- Return results for testing
    RETURN QUERY SELECT 
        total_tasks,
        total_notifications,
        created_task_ids,
        created_assignment_ids;
END;
$$ LANGUAGE plpgsql;