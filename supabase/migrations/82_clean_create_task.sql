-- Migration 82: Drop all create_task functions and create one clean version
-- This will remove all conflicting function versions

-- Drop all existing create_task functions
DROP FUNCTION IF EXISTS create_task(text);
DROP FUNCTION IF EXISTS create_task(text, text);
DROP FUNCTION IF EXISTS create_task(text, text, text);
DROP FUNCTION IF EXISTS create_task(text, text, text, text);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean, boolean);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean, boolean, boolean);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean, boolean, boolean, interval);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean, boolean, boolean, interval, bigint);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean, boolean, boolean, interval, bigint, bigint);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean, boolean, boolean, interval, bigint, bigint, uuid);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean, boolean, boolean, interval, bigint, bigint, uuid, uuid);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean, boolean, boolean, interval, bigint, bigint, uuid, uuid, text[]);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean, boolean, boolean, interval, bigint, bigint, uuid, uuid, text[], jsonb);
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, varchar, date, time, boolean, boolean, boolean, boolean, boolean, interval, bigint, bigint, uuid, uuid, text[], jsonb, boolean);

-- Drop functions with default parameters
DROP FUNCTION IF EXISTS create_task(text, text, text, text, text, text, date, time, boolean, boolean, boolean, boolean, boolean);

-- Create one clean, simple create_task function
CREATE FUNCTION create_task(
    title_param TEXT,
    description_param TEXT,
    created_by_param TEXT,
    created_by_name_param TEXT,
    created_by_role_param TEXT,
    priority_param TEXT,
    due_date_param DATE,
    due_time_param TIME,
    require_task_finished_param BOOLEAN,
    require_photo_upload_param BOOLEAN,
    require_erp_reference_param BOOLEAN,
    can_escalate_param BOOLEAN,
    can_reassign_param BOOLEAN
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
    
    -- Insert only columns that exist in the tasks table
    INSERT INTO tasks (
        title,
        description,
        created_by,
        created_by_name,
        created_by_role,
        priority,
        due_date,
        due_time,
        due_datetime,
        require_task_finished,
        require_photo_upload,
        require_erp_reference,
        can_escalate,
        can_reassign,
        status
    ) VALUES (
        title_param,
        description_param,
        created_by_param,
        created_by_name_param,
        created_by_role_param,
        priority_param,
        due_date_param,
        due_time_param,
        calculated_due_datetime,
        require_task_finished_param,
        require_photo_upload_param,
        require_erp_reference_param,
        can_escalate_param,
        can_reassign_param,
        'active'
    ) RETURNING id INTO task_id;
    
    RETURN task_id;
END;
$$ LANGUAGE plpgsql;

-- Update generate_clearance_certificate_tasks to use the clean function
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
    
    -- Create inventory manager task with NO ERP requirement
    IF receiving_record.inventory_manager_user_id IS NOT NULL THEN
        task_id := create_task(
            'New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill',
            'Delivery task for clearance certificate processing',
            created_by_user_id,
            COALESCE(created_by_name, ''),
            COALESCE(created_by_role, ''),
            'high',
            deadline_datetime::DATE,
            deadline_datetime::TIME,
            true,   -- require_task_finished
            false,  -- require_photo_upload  
            false,  -- require_erp_reference (NO ERP!)
            false,  -- can_escalate
            false   -- can_reassign
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