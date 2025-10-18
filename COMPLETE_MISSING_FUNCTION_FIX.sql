-- COMPLETE FIX: Restore missing create_task function and fix generate_clearance_certificate_tasks
-- The create_task function is missing from the database, which causes the error

-- First, create the missing create_task function
CREATE OR REPLACE FUNCTION create_task(
    title_param TEXT,
    description_param TEXT DEFAULT NULL,
    created_by_param TEXT,
    created_by_name_param TEXT DEFAULT NULL,
    created_by_role_param TEXT DEFAULT NULL,
    priority_param TEXT DEFAULT 'medium',
    category_param VARCHAR DEFAULT NULL,
    due_date_param DATE DEFAULT NULL,
    due_time_param TIME DEFAULT NULL,
    require_task_finished_param BOOLEAN DEFAULT false,
    require_photo_upload_param BOOLEAN DEFAULT false,
    require_erp_reference_param BOOLEAN DEFAULT false,
    can_escalate_param BOOLEAN DEFAULT false,
    can_reassign_param BOOLEAN DEFAULT false,
    estimated_duration_param INTERVAL DEFAULT NULL,
    department_id_param BIGINT DEFAULT NULL,
    branch_id_param BIGINT DEFAULT NULL,
    project_id_param UUID DEFAULT NULL,
    parent_task_id_param UUID DEFAULT NULL,
    tags_param TEXT[] DEFAULT NULL,
    metadata_param JSONB DEFAULT '{}',
    approval_required_param BOOLEAN DEFAULT false
)
RETURNS UUID AS $$
DECLARE
    task_id UUID;
    calculated_due_datetime TIMESTAMPTZ;
BEGIN
    -- Calculate due_datetime if due_date is provided
    IF due_date_param IS NOT NULL THEN
        calculated_due_datetime := due_date_param + COALESCE(due_time_param, '23:59:59'::TIME);
    END IF;
    
    INSERT INTO tasks (
        title,
        description,
        created_by,
        created_by_name,
        created_by_role,
        priority,
        category,
        due_date,
        due_time,
        due_datetime,
        require_task_finished,
        require_photo_upload,
        require_erp_reference,
        can_escalate,
        can_reassign,
        estimated_duration,
        department_id,
        branch_id,
        project_id,
        parent_task_id,
        tags,
        metadata,
        approval_required,
        status
    ) VALUES (
        title_param,
        description_param,
        created_by_param,
        created_by_name_param,
        created_by_role_param,
        priority_param,
        category_param,
        due_date_param,
        due_time_param,
        calculated_due_datetime,
        require_task_finished_param,
        require_photo_upload_param,
        require_erp_reference_param,
        can_escalate_param,
        can_reassign_param,
        estimated_duration_param,
        department_id_param,
        branch_id_param,
        project_id_param,
        parent_task_id_param,
        tags_param,
        metadata_param,
        approval_required_param,
        CASE WHEN approval_required_param THEN 'pending' ELSE 'active' END
    ) RETURNING id INTO task_id;
    
    RETURN task_id;
END;
$$ LANGUAGE plpgsql;

-- Now fix the generate_clearance_certificate_tasks function with NO ERP requirement
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
    
    -- Create ONLY inventory manager task with NO ERP requirement
    IF receiving_record.inventory_manager_user_id IS NOT NULL THEN
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
            receiving_record.branch_id,                                                 -- branch_id_param
            NULL,                                                                       -- project_id_param
            NULL,                                                                       -- parent_task_id_param
            ARRAY['delivery'],                                                          -- tags_param
            '{}',                                                                       -- metadata_param
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