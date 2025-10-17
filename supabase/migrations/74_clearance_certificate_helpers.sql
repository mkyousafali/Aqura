-- =============================================
-- Additional Helper Functions for Clearance Certificate Process
-- =============================================

-- Function to handle the complete clearance certificate generation process
-- This is the main function that should be called from the frontend
CREATE OR REPLACE FUNCTION process_clearance_certificate_generation(
    receiving_record_id_param UUID,
    clearance_certificate_url_param TEXT,
    generated_by_user_id TEXT,
    generated_by_name TEXT DEFAULT NULL,
    generated_by_role TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    result RECORD;
    response JSONB;
BEGIN
    -- Validate that receiving record exists
    IF NOT EXISTS (SELECT 1 FROM receiving_records WHERE id = receiving_record_id_param) THEN
        RAISE EXCEPTION 'Receiving record with ID % does not exist', receiving_record_id_param;
    END IF;
    
    -- Check if tasks have already been generated for this receiving record
    IF EXISTS (SELECT 1 FROM receiving_tasks WHERE receiving_record_id = receiving_record_id_param) THEN
        RAISE EXCEPTION 'Tasks have already been generated for this receiving record';
    END IF;
    
    -- Generate all the tasks
    SELECT * INTO result 
    FROM generate_clearance_certificate_tasks(
        receiving_record_id_param,
        clearance_certificate_url_param,
        generated_by_user_id,
        generated_by_name,
        generated_by_role
    );
    
    -- Build response JSON
    response := jsonb_build_object(
        'success', true,
        'receiving_record_id', receiving_record_id_param,
        'clearance_certificate_url', clearance_certificate_url_param,
        'tasks_created', result.task_count,
        'notifications_sent', result.notification_count,
        'task_ids', result.task_ids,
        'assignment_ids', result.assignment_ids,
        'generated_at', now(),
        'generated_by', jsonb_build_object(
            'user_id', generated_by_user_id,
            'name', generated_by_name,
            'role', generated_by_role
        )
    );
    
    -- Log the successful generation
    RAISE NOTICE 'Clearance certificate tasks generated successfully: % tasks, % notifications', 
                 result.task_count, result.notification_count;
    
    RETURN response;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Return error response
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'error_code', SQLSTATE
        );
END;
$$ LANGUAGE plpgsql;

-- Function to get tasks for a specific receiving record
CREATE OR REPLACE FUNCTION get_tasks_for_receiving_record(
    receiving_record_id_param UUID
)
RETURNS TABLE(
    task_id UUID,
    assignment_id UUID,
    role_type VARCHAR,
    assigned_user_id UUID,
    task_title VARCHAR,
    task_description TEXT,
    task_status VARCHAR,
    assignment_status VARCHAR,
    priority VARCHAR,
    deadline_datetime TIMESTAMPTZ,
    requires_erp_reference BOOLEAN,
    requires_original_bill_upload BOOLEAN,
    requires_reassignment BOOLEAN,
    erp_reference_number VARCHAR,
    original_bill_uploaded BOOLEAN,
    task_completed BOOLEAN,
    is_overdue BOOLEAN,
    can_be_completed BOOLEAN,
    clearance_certificate_url TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rtd.task_id,
        rtd.assignment_id,
        rtd.role_type,
        rtd.assigned_user_id,
        rtd.task_title,
        rtd.task_description,
        rtd.task_status,
        rtd.assignment_status,
        rtd.task_priority,
        rtd.assignment_deadline,
        rtd.requires_erp_reference,
        rtd.requires_original_bill_upload,
        rtd.requires_reassignment,
        rtd.erp_reference_number,
        rtd.original_bill_uploaded,
        rtd.task_completed,
        rtd.is_overdue,
        rtd.can_be_completed,
        rtd.clearance_certificate_url,
        rtd.created_at
    FROM receiving_tasks_detailed rtd
    WHERE rtd.receiving_record_id = receiving_record_id_param
    ORDER BY 
        CASE rtd.role_type
            WHEN 'branch_manager' THEN 1
            WHEN 'inventory_manager' THEN 2
            WHEN 'purchase_manager' THEN 3
            WHEN 'night_supervisor' THEN 4
            WHEN 'warehouse_handler' THEN 5
            WHEN 'shelf_stocker' THEN 6
            WHEN 'accountant' THEN 7
            ELSE 8
        END,
        rtd.created_at;
END;
$$ LANGUAGE plpgsql;

-- Function to reassign a receiving task
CREATE OR REPLACE FUNCTION reassign_receiving_task(
    receiving_task_id_param UUID,
    new_assigned_user_id UUID,
    reassigned_by_user_id TEXT,
    reassignment_reason TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    receiving_task RECORD;
    new_assignment_id UUID;
    response JSONB;
BEGIN
    -- Get the current receiving task
    SELECT * INTO receiving_task 
    FROM receiving_tasks 
    WHERE id = receiving_task_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving task not found: %', receiving_task_id_param;
    END IF;
    
    -- Check if reassignment is allowed for this task type
    IF NOT receiving_task.requires_reassignment THEN
        RAISE EXCEPTION 'This task type does not allow reassignment';
    END IF;
    
    -- Reassign the task assignment
    SELECT reassign_task(
        receiving_task.assignment_id,
        new_assigned_user_id::TEXT,
        NULL, -- branch_id
        reassigned_by_user_id,
        reassignment_reason
    ) INTO new_assignment_id;
    
    -- Update the receiving task with new assignment
    UPDATE receiving_tasks 
    SET 
        assignment_id = new_assignment_id,
        assigned_user_id = new_assigned_user_id,
        updated_at = now()
    WHERE id = receiving_task_id_param;
    
    -- Create notification for new assignee
    INSERT INTO notifications (
        title, message, created_by, created_by_name,
        target_type, target_users, type, priority,
        task_id, task_assignment_id, has_attachments,
        metadata
    ) VALUES (
        'Task Reassigned to You',
        format('A %s task has been reassigned to you. Reason: %s', 
               receiving_task.role_type, 
               COALESCE(reassignment_reason, 'No reason provided')),
        reassigned_by_user_id, 'System',
        'specific_users', to_jsonb(ARRAY[new_assigned_user_id::TEXT]),
        'task', 'medium',
        receiving_task.task_id, new_assignment_id,
        receiving_task.clearance_certificate_url IS NOT NULL,
        jsonb_build_object(
            'receiving_task_id', receiving_task_id_param,
            'original_assignee', receiving_task.assigned_user_id,
            'reassignment_reason', reassignment_reason
        )
    );
    
    response := jsonb_build_object(
        'success', true,
        'receiving_task_id', receiving_task_id_param,
        'new_assignment_id', new_assignment_id,
        'new_assigned_user_id', new_assigned_user_id,
        'reassigned_at', now()
    );
    
    RETURN response;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- Function to complete a receiving task with requirements
CREATE OR REPLACE FUNCTION complete_receiving_task(
    receiving_task_id_param UUID,
    user_id_param UUID,
    erp_reference_param VARCHAR DEFAULT NULL,
    original_bill_file_path_param TEXT DEFAULT NULL,
    completion_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    receiving_task RECORD;
    task_completed BOOLEAN;
    response JSONB;
BEGIN
    -- Get the receiving task
    SELECT * INTO receiving_task 
    FROM receiving_tasks 
    WHERE id = receiving_task_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving task not found: %', receiving_task_id_param;
    END IF;
    
    -- Verify user is assigned to this task
    IF receiving_task.assigned_user_id != user_id_param THEN
        RAISE EXCEPTION 'User not authorized to complete this task';
    END IF;
    
    -- Check if task is already completed
    IF receiving_task.task_completed THEN
        RAISE EXCEPTION 'Task is already completed';
    END IF;
    
    -- Update task with completion data
    SELECT update_receiving_task_completion(
        receiving_task_id_param,
        erp_reference_param,
        original_bill_file_path_param IS NOT NULL,
        original_bill_file_path_param
    ) INTO task_completed;
    
    -- If task was successfully completed, add completion notes if column exists
    IF task_completed THEN
        -- Try to update completion notes, but don't fail if column doesn't exist
        BEGIN
            UPDATE task_assignments 
            SET completion_notes = completion_notes
            WHERE id = receiving_task.assignment_id;
        EXCEPTION
            WHEN undefined_column THEN
                -- Ignore error if completion_notes column doesn't exist
                NULL;
        END;
        
        -- Create completion notification
        INSERT INTO notifications (
            title, message, created_by,
            target_type, target_users, type, priority,
            task_id, task_assignment_id,
            metadata
        ) VALUES (
            'Task Completed',
            format('Task "%s" has been completed successfully', receiving_task.role_type),
            user_id_param::TEXT,
            'specific_users', to_jsonb(ARRAY[user_id_param::TEXT]),
            'success', 'low',
            receiving_task.task_id, receiving_task.assignment_id,
            jsonb_build_object(
                'receiving_task_id', receiving_task_id_param,
                'completion_notes', completion_notes
            )
        );
    END IF;
    
    response := jsonb_build_object(
        'success', true,
        'task_completed', task_completed,
        'receiving_task_id', receiving_task_id_param,
        'completed_at', CASE WHEN task_completed THEN now() ELSE NULL END,
        'requirements_met', jsonb_build_object(
            'erp_reference_provided', erp_reference_param IS NOT NULL,
            'original_bill_uploaded', original_bill_file_path_param IS NOT NULL
        )
    );
    
    RETURN response;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- Function to get user's receiving tasks dashboard
CREATE OR REPLACE FUNCTION get_user_receiving_tasks_dashboard(
    user_id_param UUID
)
RETURNS JSONB AS $$
DECLARE
    dashboard JSONB;
    stats RECORD;
    recent_tasks JSONB;
    overdue_tasks JSONB;
BEGIN
    -- Get task statistics for user
    SELECT 
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE task_completed = true) as completed_tasks,
        COUNT(*) FILTER (WHERE task_completed = false) as pending_tasks,
        COUNT(*) FILTER (WHERE is_overdue = true AND task_completed = false) as overdue_tasks,
        COUNT(*) FILTER (WHERE requires_erp_reference = true AND erp_reference_number IS NULL) as needs_erp,
        COUNT(*) FILTER (WHERE requires_original_bill_upload = true AND original_bill_uploaded = false) as needs_upload
    INTO stats
    FROM receiving_tasks_detailed
    WHERE assigned_user_id = user_id_param;
    
    -- Get recent tasks (last 10)
    SELECT jsonb_agg(
        jsonb_build_object(
            'task_id', task_id,
            'title', task_title,
            'role_type', role_type,
            'status', assignment_status,
            'priority', task_priority,
            'deadline', assignment_deadline,
            'is_overdue', is_overdue,
            'requires_erp_reference', requires_erp_reference,
            'requires_original_bill_upload', requires_original_bill_upload,
            'can_be_completed', can_be_completed,
            'created_at', created_at
        )
    ) INTO recent_tasks
    FROM (
        SELECT * FROM get_receiving_tasks_for_user(user_id_param, NULL, 10)
    ) recent;
    
    -- Get overdue tasks
    SELECT jsonb_agg(
        jsonb_build_object(
            'task_id', task_id,
            'title', title,
            'role_type', role_type,
            'deadline', deadline_datetime,
            'hours_overdue', EXTRACT(EPOCH FROM (now() - deadline_datetime)) / 3600
        )
    ) INTO overdue_tasks
    FROM get_receiving_tasks_for_user(user_id_param, NULL, 50)
    WHERE is_overdue = true;
    
    -- Build dashboard response
    dashboard := jsonb_build_object(
        'user_id', user_id_param,
        'statistics', jsonb_build_object(
            'total_tasks', COALESCE(stats.total_tasks, 0),
            'completed_tasks', COALESCE(stats.completed_tasks, 0),
            'pending_tasks', COALESCE(stats.pending_tasks, 0),
            'overdue_tasks', COALESCE(stats.overdue_tasks, 0),
            'needs_erp_reference', COALESCE(stats.needs_erp, 0),
            'needs_original_bill_upload', COALESCE(stats.needs_upload, 0),
            'completion_rate', CASE 
                WHEN COALESCE(stats.total_tasks, 0) > 0 
                THEN ROUND((COALESCE(stats.completed_tasks, 0) * 100.0) / stats.total_tasks, 2)
                ELSE 0 
            END
        ),
        'recent_tasks', COALESCE(recent_tasks, '[]'::jsonb),
        'overdue_tasks', COALESCE(overdue_tasks, '[]'::jsonb),
        'last_updated', now()
    );
    
    RETURN dashboard;
END;
$$ LANGUAGE plpgsql;

-- Function to check if original bill upload is required before task completion
CREATE OR REPLACE FUNCTION validate_task_completion_requirements(
    receiving_task_id_param UUID,
    user_id_param UUID
)
RETURNS JSONB AS $$
DECLARE
    receiving_task RECORD;
    receiving_record RECORD;
    validation_result JSONB;
    missing_requirements TEXT[] := '{}';
BEGIN
    -- Get receiving task
    SELECT * INTO receiving_task 
    FROM receiving_tasks 
    WHERE id = receiving_task_id_param AND assigned_user_id = user_id_param;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'valid', false,
            'error', 'Task not found or user not authorized'
        );
    END IF;
    
    -- Get receiving record
    SELECT * INTO receiving_record 
    FROM receiving_records 
    WHERE id = receiving_task.receiving_record_id;
    
    -- Check ERP reference requirement
    IF receiving_task.requires_erp_reference AND receiving_task.erp_reference_number IS NULL THEN
        missing_requirements := missing_requirements || 'ERP reference number required';
    END IF;
    
    -- Check original bill upload requirement (especially for inventory manager)
    IF receiving_task.requires_original_bill_upload THEN
        -- Check if original bill has been uploaded to receiving record
        IF receiving_record.original_bill_url IS NULL OR receiving_record.original_bill_url = '' THEN
            missing_requirements := missing_requirements || 'Original bill must be uploaded through Receive Record window';
        ELSE
            -- Auto-update the receiving task if bill is already uploaded
            UPDATE receiving_tasks 
            SET 
                original_bill_uploaded = true,
                original_bill_file_path = receiving_record.original_bill_url,
                updated_at = now()
            WHERE id = receiving_task_id_param;
        END IF;
    END IF;
    
    validation_result := jsonb_build_object(
        'valid', array_length(missing_requirements, 1) IS NULL,
        'missing_requirements', missing_requirements,
        'task_id', receiving_task.task_id,
        'role_type', receiving_task.role_type,
        'requirements', jsonb_build_object(
            'erp_reference_required', receiving_task.requires_erp_reference,
            'erp_reference_provided', receiving_task.erp_reference_number IS NOT NULL,
            'original_bill_upload_required', receiving_task.requires_original_bill_upload,
            'original_bill_uploaded', receiving_task.original_bill_uploaded OR receiving_record.original_bill_url IS NOT NULL,
            'task_finished_mark_required', receiving_task.requires_task_finished_mark
        )
    );
    
    RETURN validation_result;
END;
$$ LANGUAGE plpgsql;

-- Clearance certificate helper functions created successfully