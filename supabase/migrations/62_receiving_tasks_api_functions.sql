-- Fix Missing Receiving Tasks API Functions
-- This migration creates the missing database functions needed by the receiving-tasks API

BEGIN;

-- Drop existing functions if they exist (to handle return type changes)
DROP FUNCTION IF EXISTS get_tasks_for_receiving_record(uuid);
DROP FUNCTION IF EXISTS process_clearance_certificate_generation(uuid, text, uuid, text, text);
DROP FUNCTION IF EXISTS process_clearance_certificate_generation(uuid, text, text, text, text);
DROP FUNCTION IF EXISTS get_receiving_tasks_for_user(uuid, text, integer);
DROP FUNCTION IF EXISTS get_receiving_task_statistics(integer, date, date);

-- Drop any other variations that might exist
DROP FUNCTION IF EXISTS create_receiving_tasks CASCADE;
DROP FUNCTION IF EXISTS process_clearance_certificate_generation CASCADE;

-- Function to get tasks for a specific receiving record
CREATE OR REPLACE FUNCTION get_tasks_for_receiving_record(receiving_record_id_param UUID)
RETURNS TABLE (
    task_id UUID,
    task_title TEXT,
    task_description TEXT,
    assigned_to_user_id UUID,
    assigned_to_username TEXT,
    status TEXT,
    priority TEXT,
    due_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    attachment_url TEXT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as task_id,
        t.title as task_title,
        t.description as task_description,
        ta.assigned_to_user_id::uuid as assigned_to_user_id,
        u.username as assigned_to_username,
        t.status,
        t.priority,
        t.due_datetime as due_date,
        t.created_at,
        NULL::timestamptz as completed_at,
        NULL::text as attachment_url
    FROM tasks t
    LEFT JOIN task_assignments ta ON ta.task_id = t.id
    LEFT JOIN users u ON u.id::text = ta.assigned_to_user_id
    WHERE t.description LIKE '%' || receiving_record_id_param || '%'
    ORDER BY t.created_at DESC;
END;
$$;

-- Function to process clearance certificate generation and create tasks
CREATE OR REPLACE FUNCTION process_clearance_certificate_generation(
    receiving_record_id_param UUID,
    clearance_certificate_url_param TEXT,
    generated_by_user_id UUID,
    generated_by_name TEXT DEFAULT NULL,
    generated_by_role TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    receiving_rec RECORD;
    vendor_rec RECORD;
    received_by_user RECORD;
    task_count INTEGER := 0;
    notification_count INTEGER := 0;
    new_task_id UUID;
    user_rec RECORD;
    result JSON;
    notification_message TEXT;
    deadline_time TIMESTAMPTZ;
BEGIN
    -- Get the receiving record details
    SELECT * INTO receiving_rec 
    FROM receiving_records 
    WHERE id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Receiving record not found',
            'error_code', 'RECORD_NOT_FOUND'
        );
    END IF;
    
    -- Get vendor details
    SELECT * INTO vendor_rec
    FROM vendors 
    WHERE erp_vendor_id = receiving_rec.vendor_id 
    AND branch_id = receiving_rec.branch_id;
    
    -- Get received by user details
    SELECT * INTO received_by_user
    FROM users 
    WHERE id = receiving_rec.user_id;
    
    -- Calculate deadline (24 hours from now)
    deadline_time := NOW() + INTERVAL '24 hours';
    
    -- Update the receiving record with certificate URL
    UPDATE receiving_records 
    SET 
        certificate_url = clearance_certificate_url_param,
        updated_at = NOW()
    WHERE id = receiving_record_id_param;
    
    -- Create tasks for all assigned users from receiving record
    DECLARE
        user_ids UUID[];
        user_id UUID;
        notification_id UUID;
        task_title TEXT;
        task_description TEXT;
    BEGIN
        -- Collect all user IDs from the receiving record
        user_ids := ARRAY[]::UUID[];
        
        -- Add accountant
        IF receiving_rec.accountant_user_id IS NOT NULL THEN
            user_ids := user_ids || receiving_rec.accountant_user_id;
        END IF;
        
        -- Add branch manager
        IF receiving_rec.branch_manager_user_id IS NOT NULL THEN
            user_ids := user_ids || receiving_rec.branch_manager_user_id;
        END IF;
        
        -- Add purchasing manager
        IF receiving_rec.purchasing_manager_user_id IS NOT NULL THEN
            user_ids := user_ids || receiving_rec.purchasing_manager_user_id;
        END IF;
        
        -- Add inventory manager
        IF receiving_rec.inventory_manager_user_id IS NOT NULL THEN
            user_ids := user_ids || receiving_rec.inventory_manager_user_id;
        END IF;
        
        -- Add shelf stockers (array field)
        IF receiving_rec.shelf_stocker_user_ids IS NOT NULL THEN
            user_ids := user_ids || receiving_rec.shelf_stocker_user_ids;
        END IF;
        
        -- Add night supervisors (array field)
        IF receiving_rec.night_supervisor_user_ids IS NOT NULL THEN
            user_ids := user_ids || receiving_rec.night_supervisor_user_ids;
        END IF;
        
        -- Add warehouse handlers (array field)
        IF receiving_rec.warehouse_handler_user_ids IS NOT NULL THEN
            user_ids := user_ids || receiving_rec.warehouse_handler_user_ids;
        END IF;
        
        -- Create tasks for each user
        FOREACH user_id IN ARRAY user_ids
        LOOP
            -- Get user details
            SELECT u.* INTO user_rec
            FROM users u
            WHERE u.id = user_id;
            
            IF FOUND THEN
                -- Determine task based on user role
                IF user_id = receiving_rec.accountant_user_id THEN
                    task_title := 'Filing Original Bill Task';
                    task_description := format('File original bill for receiving record %s. 
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)
Certificate: %s', 
                        receiving_rec.id, 
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount, 
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
                        clearance_certificate_url_param);
                ELSIF user_id = receiving_rec.branch_manager_user_id THEN
                    task_title := 'New Delivery Arrived – Start Placing';
                    task_description := format('Manage delivery placement for receiving record %s.
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)', 
                        receiving_rec.id,
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                ELSIF user_id = receiving_rec.purchasing_manager_user_id THEN
                    task_title := 'New Delivery Arrived – Price Check';
                    task_description := format('Verify pricing for receiving record %s.
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received time: %s
Deadline: %s (24 hours)', 
                        receiving_rec.id,
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                ELSIF user_id = receiving_rec.inventory_manager_user_id THEN
                    task_title := 'New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill';
                    task_description := format('Process inventory for receiving record %s.
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)', 
                        receiving_rec.id,
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                ELSIF user_id = ANY(receiving_rec.shelf_stocker_user_ids) THEN
                    task_title := 'New Delivery Arrived – Confirm Product is Placed';
                    task_description := format('Stock placement for receiving record %s.
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)', 
                        receiving_rec.id,
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                ELSIF user_id = ANY(receiving_rec.night_supervisor_user_ids) THEN
                    task_title := 'New Delivery Arrived – Confirm Product is Placed';
                    task_description := format('Supervise delivery placement for receiving record %s.
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)', 
                        receiving_rec.id,
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                ELSIF user_id = ANY(receiving_rec.warehouse_handler_user_ids) THEN
                    task_title := 'New Delivery Arrived – Confirm Product is Moved to Display';
                    task_description := format('Handle warehouse operations for receiving record %s.
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)', 
                        receiving_rec.id,
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                ELSE
                    task_title := 'New Delivery Processing Task';
                    task_description := format('Review and process receiving record %s.
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)', 
                        receiving_rec.id,
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                END IF;
                
                -- Create task
                INSERT INTO tasks (
                    title,
                    description,
                    created_by,
                    status,
                    priority,
                    due_datetime,
                    created_at
                ) VALUES (
                    task_title,
                    task_description,
                    generated_by_user_id::text,
                    'pending',
                    'high',
                    deadline_time,
                    NOW()
                ) RETURNING id INTO new_task_id;
                
                -- Create task assignment
                INSERT INTO task_assignments (
                    task_id,
                    assignment_type,
                    assigned_to_user_id,
                    assigned_by,
                    assigned_at,
                    deadline_datetime,
                    deadline_date,
                    deadline_time,
                    status
                ) VALUES (
                    new_task_id,
                    'user',
                    user_id::text,
                    generated_by_user_id::text,
                    NOW(),
                    deadline_time,
                    deadline_time::date,
                    deadline_time::time,
                    'assigned'
                );
                
                task_count := task_count + 1;
                
                -- Create detailed notification message
                notification_message := format('New Task Assigned: %s

Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)

Task Details: %s', 
                    task_title,
                    COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                    receiving_rec.vendor_id,
                    receiving_rec.bill_amount,
                    COALESCE(receiving_rec.bill_number, 'N/A'),
                    DATE(receiving_rec.created_at),
                    COALESCE(received_by_user.username, 'Unknown User'),
                    TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                    TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
                    task_title);
                
                -- Create notification
                INSERT INTO notifications (
                    title,
                    message,
                    type,
                    task_id,
                    created_by
                ) VALUES (
                    'New Task Assigned',
                    notification_message,
                    'task_assignment',
                    new_task_id,
                    generated_by_user_id::text
                ) RETURNING id INTO notification_id;
                
                -- Add recipient
                INSERT INTO notification_recipients (
                    notification_id,
                    user_id,
                    is_read
                ) VALUES (
                    notification_id,
                    user_id,
                    false
                );
                
                notification_count := notification_count + 1;
            END IF;
        END LOOP;
    END;
    
    -- Return success result
    result := json_build_object(
        'success', true,
        'tasks_created', task_count,
        'notifications_sent', notification_count,
        'receiving_record_id', receiving_record_id_param,
        'certificate_url', clearance_certificate_url_param
    );
    
    RETURN result;
    
EXCEPTION WHEN OTHERS THEN
    -- Return error result
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM,
        'error_code', 'PROCESSING_ERROR'
    );
END;
$$;

-- Function to get receiving tasks for a user
CREATE OR REPLACE FUNCTION get_receiving_tasks_for_user(
    user_id_param UUID,
    status_filter TEXT DEFAULT NULL,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE (
    task_id UUID,
    task_title TEXT,
    task_description TEXT,
    receiving_record_id UUID,
    vendor_name TEXT,
    bill_amount DECIMAL,
    bill_number TEXT,
    status TEXT,
    priority TEXT,
    due_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    attachment_url TEXT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as task_id,
        t.title as task_title,
        t.description as task_description,
        rr.id as receiving_record_id,
        COALESCE(v.vendor_name, 'Unknown Vendor') as vendor_name,
        rr.bill_amount,
        rr.bill_number,
        t.status,
        t.priority,
        t.due_datetime as due_date,
        t.created_at,
        NULL::timestamptz as completed_at,
        NULL::text as attachment_url
    FROM tasks t
    LEFT JOIN task_assignments ta ON ta.task_id = t.id
    LEFT JOIN receiving_records rr ON rr.id::text = SUBSTRING(t.description FROM 'receiving record ([0-9a-f-]+)')
    LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
    WHERE ta.assigned_to_user_id = user_id_param::text
    AND (status_filter IS NULL OR t.status = status_filter)
    AND t.description LIKE '%receiving record%'
    ORDER BY t.created_at DESC
    LIMIT limit_count;
END;
$$;

-- Function to get receiving task statistics
CREATE OR REPLACE FUNCTION get_receiving_task_statistics(
    branch_id_param INTEGER DEFAULT NULL,
    date_from DATE DEFAULT NULL,
    date_to DATE DEFAULT NULL
)
RETURNS TABLE (
    total_tasks BIGINT,
    pending_tasks BIGINT,
    in_progress_tasks BIGINT,
    completed_tasks BIGINT,
    overdue_tasks BIGINT,
    high_priority_tasks BIGINT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE t.status = 'pending') as pending_tasks,
        COUNT(*) FILTER (WHERE t.status = 'in_progress') as in_progress_tasks,
        COUNT(*) FILTER (WHERE t.status = 'completed') as completed_tasks,
        COUNT(*) FILTER (WHERE t.status != 'completed' AND t.due_datetime < NOW()) as overdue_tasks,
        COUNT(*) FILTER (WHERE t.priority = 'high') as high_priority_tasks
    FROM tasks t
    LEFT JOIN receiving_records rr ON rr.id::text = SUBSTRING(t.description FROM 'receiving record ([0-9a-f-]+)')
    WHERE t.description LIKE '%receiving record%'
    AND (branch_id_param IS NULL OR rr.branch_id = branch_id_param)
    AND (date_from IS NULL OR DATE(t.created_at) >= date_from)
    AND (date_to IS NULL OR DATE(t.created_at) <= date_to);
END;
$$;

COMMIT;