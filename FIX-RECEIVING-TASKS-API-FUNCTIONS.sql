-- Fix Missing Receiving Tasks API Functions
-- This migration creates the missing database functions needed by the receiving-tasks API

BEGIN;

-- Function to get tasks for a specific receiving record
CREATE OR REPLACE FUNCTION get_tasks_for_receiving_record(receiving_record_id_param UUID)
RETURNS TABLE (
    task_id UUID,
    task_title TEXT,
    task_description TEXT,
    assigned_to_user_id UUID,
    assigned_to_username TEXT,
    assigned_to_role TEXT,
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
        t.assigned_to_user_id,
        u.username as assigned_to_username,
        ur.role_type as assigned_to_role,
        t.status,
        t.priority,
        t.due_date,
        t.created_at,
        t.completed_at,
        t.attachment_url
    FROM tasks t
    LEFT JOIN users u ON u.id = t.assigned_to_user_id
    LEFT JOIN user_roles ur ON ur.user_id = u.id
    WHERE t.receiving_record_id = receiving_record_id_param
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
    task_count INTEGER := 0;
    notification_count INTEGER := 0;
    new_task_id UUID;
    user_rec RECORD;
    result JSON;
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
    
    -- Update the receiving record with certificate URL
    UPDATE receiving_records 
    SET 
        certificate_url = clearance_certificate_url_param,
        updated_at = NOW()
    WHERE id = receiving_record_id_param;
    
    -- Create task for accountant if accountant_user_id exists
    IF receiving_rec.accountant_user_id IS NOT NULL THEN
        -- Get accountant details
        SELECT u.*, ur.role_type INTO user_rec
        FROM users u
        LEFT JOIN user_roles ur ON ur.user_id = u.id
        WHERE u.id = receiving_rec.accountant_user_id;
        
        IF FOUND THEN
            -- Create task for accountant
            INSERT INTO tasks (
                title,
                description,
                assigned_to_user_id,
                assigned_by_user_id,
                receiving_record_id,
                status,
                priority,
                due_date,
                attachment_url,
                created_at
            ) VALUES (
                'New payment made — enter into the ERP, update the ERP reference, and upload the payment receipt',
                format('Process payment for receiving record %s. Bill Amount: $%s, Vendor: %s', 
                    receiving_rec.id, 
                    receiving_rec.bill_amount, 
                    receiving_rec.vendor_name
                ),
                receiving_rec.accountant_user_id,
                generated_by_user_id,
                receiving_record_id_param,
                'pending',
                'high',
                NOW() + INTERVAL '24 hours',
                clearance_certificate_url_param,
                NOW()
            ) RETURNING id INTO new_task_id;
            
            task_count := task_count + 1;
            
            -- Create notification for accountant
            INSERT INTO notifications (
                user_id,
                title,
                message,
                type,
                reference_id,
                reference_type,
                created_at,
                is_read
            ) VALUES (
                receiving_rec.accountant_user_id,
                'New Payment Task Assigned',
                format('You have been assigned a payment processing task for receiving record %s', receiving_rec.id),
                'task_assignment',
                new_task_id,
                'task',
                NOW(),
                false
            );
            
            notification_count := notification_count + 1;
        END IF;
    END IF;
    
    -- Create tasks for other relevant roles (warehouse manager, supervisor, etc.)
    -- This can be expanded based on business requirements
    
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
        t.receiving_record_id,
        rr.vendor_name,
        rr.bill_amount,
        rr.bill_number,
        t.status,
        t.priority,
        t.due_date,
        t.created_at,
        t.completed_at,
        t.attachment_url
    FROM tasks t
    LEFT JOIN receiving_records rr ON rr.id = t.receiving_record_id
    WHERE t.assigned_to_user_id = user_id_param
    AND (status_filter IS NULL OR t.status = status_filter)
    AND t.receiving_record_id IS NOT NULL
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
        COUNT(*) FILTER (WHERE t.status != 'completed' AND t.due_date < NOW()) as overdue_tasks,
        COUNT(*) FILTER (WHERE t.priority = 'high') as high_priority_tasks
    FROM tasks t
    LEFT JOIN receiving_records rr ON rr.id = t.receiving_record_id
    WHERE t.receiving_record_id IS NOT NULL
    AND (branch_id_param IS NULL OR rr.branch_id = branch_id_param)
    AND (date_from IS NULL OR DATE(t.created_at) >= date_from)
    AND (date_to IS NULL OR DATE(t.created_at) <= date_to);
END;
$$;

COMMIT;