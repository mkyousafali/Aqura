-- Migration: Fix clearance certificate task generation to set deadline fields and require_task_finished
-- This fixes the process_clearance_certificate_generation function to properly set:
-- 1. deadline_date (extracted from deadline_datetime)
-- 2. deadline_time (extracted from deadline_datetime) 
-- 3. require_task_finished = true (instead of false)

CREATE OR REPLACE FUNCTION process_clearance_certificate_generation(
    receiving_record_id_param UUID,
    clearance_certificate_url_param TEXT,
    generated_by_user_id UUID,
    generated_by_name TEXT DEFAULT NULL,
    generated_by_role TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    receiving_rec RECORD;
    vendor_rec RECORD;
    received_by_user RECORD;
    task_count INTEGER := 0;
    notification_count INTEGER := 0;
    new_task_id UUID;
    deadline_time TIMESTAMPTZ;
    current_user_deadline TIMESTAMPTZ;  -- Variable to hold deadline for current user
    result JSON;
    user_ids UUID[];
    user_id UUID;
    notification_id UUID;
    task_title TEXT;
    task_description TEXT;
    notification_message TEXT;
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
    WHERE erp_vendor_id = receiving_rec.vendor_id;
    
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
    
    -- Add night supervisor
    IF receiving_rec.night_supervisor_user_ids IS NOT NULL AND array_length(receiving_rec.night_supervisor_user_ids, 1) > 0 THEN
        FOR i IN 1..array_length(receiving_rec.night_supervisor_user_ids, 1) LOOP
            user_ids := user_ids || receiving_rec.night_supervisor_user_ids[i];
        END LOOP;
    END IF;
    
    -- Add warehouse handlers
    IF receiving_rec.warehouse_handler_user_ids IS NOT NULL AND array_length(receiving_rec.warehouse_handler_user_ids, 1) > 0 THEN
        FOR i IN 1..array_length(receiving_rec.warehouse_handler_user_ids, 1) LOOP
            user_ids := user_ids || receiving_rec.warehouse_handler_user_ids[i];
        END LOOP;
    END IF;
    
    -- Add shelf stockers
    IF receiving_rec.shelf_stocker_user_ids IS NOT NULL AND array_length(receiving_rec.shelf_stocker_user_ids, 1) > 0 THEN
        FOR i IN 1..array_length(receiving_rec.shelf_stocker_user_ids, 1) LOOP
            user_ids := user_ids || receiving_rec.shelf_stocker_user_ids[i];
        END LOOP;
    END IF;
    
    -- Create tasks and notifications for each assigned user
    FOREACH user_id IN ARRAY user_ids
    LOOP
        IF user_id IS NOT NULL THEN
            -- Set deadline based on user role (72 hours for purchasing manager, 24 hours for others)
            IF user_id = receiving_rec.purchasing_manager_user_id THEN
                current_user_deadline := NOW() + INTERVAL '72 hours';  -- 72 hours for purchasing manager
            ELSE
                current_user_deadline := deadline_time;  -- 24 hours for everyone else
            END IF;
            
            -- Determine task title and description based on user role
            IF user_id = receiving_rec.accountant_user_id THEN
                task_title := 'New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill';
                task_description := format('🧾 Task for Accountant

Process payment and documentation for this receiving record.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Deadline: %s (24 hours from assignment)

Tasks Required:
1. Enter payment details into Purchase ERP system
2. Upload original bill document
3. Update ERP reference number
4. Confirm task completion in system

Clearance Certificate: %s', 
                    COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                    COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                    receiving_rec.vendor_id,
                    receiving_rec.bill_amount,
                    COALESCE(receiving_rec.bill_number, 'N/A'),
                    DATE(receiving_rec.created_at),
                    COALESCE(received_by_user.username, 'Unknown User'),
                    TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
                    clearance_certificate_url_param);
                    
                notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: %s

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Deadline: %s (24 hours)

Please process the payment and upload the original bill as required.', 
                    task_title,
                    COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                    COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                    receiving_rec.vendor_id,
                    receiving_rec.bill_amount,
                    COALESCE(receiving_rec.bill_number, 'N/A'),
                    DATE(receiving_rec.created_at),
                    COALESCE(received_by_user.username, 'Unknown User'),
                    TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                    
            ELSIF user_id = receiving_rec.branch_manager_user_id THEN
                task_title := 'New Delivery Arrived – Start Placing';
                task_description := format('🧾 Task for Branch Manager

Manage the delivery placement process for this receiving record.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Deadline: %s (24 hours from assignment)

Ensure all received products are verified, placed correctly, and shelves are updated accordingly.
Once the placement is completed, confirm task completion in the system.', 
                    COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                    COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                    receiving_rec.vendor_id,
                    receiving_rec.bill_amount,
                    COALESCE(receiving_rec.bill_number, 'N/A'),
                    DATE(receiving_rec.created_at),
                    COALESCE(received_by_user.username, 'Unknown User'),
                    TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                    
                notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: %s

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Deadline: %s (24 hours)

Please start the delivery placement process and manage the team accordingly.', 
                    task_title,
                    COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                    COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                    receiving_rec.vendor_id,
                    receiving_rec.bill_amount,
                    COALESCE(receiving_rec.bill_number, 'N/A'),
                    DATE(receiving_rec.created_at),
                    COALESCE(received_by_user.username, 'Unknown User'),
                    TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                    
            ELSIF user_id = receiving_rec.purchasing_manager_user_id THEN
                task_title := 'New Delivery Arrived – Price Check';
                task_description := format('🧾 Task for Purchasing Manager

Perform price verification for this receiving record.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Deadline: %s (72 hours from assignment)

Verify pricing accuracy and update any discrepancies in the system.', 
                    COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                    COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                    receiving_rec.vendor_id,
                    receiving_rec.bill_amount,
                    COALESCE(receiving_rec.bill_number, 'N/A'),
                    DATE(receiving_rec.created_at),
                    COALESCE(received_by_user.username, 'Unknown User'),
                    TO_CHAR(current_user_deadline, 'YYYY-MM-DD HH24:MI:SS'));
                    
                notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: %s

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Deadline: %s (72 hours)

Please verify the pricing for this delivery.', 
                    task_title,
                    COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                    COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                    receiving_rec.vendor_id,
                    receiving_rec.bill_amount,
                    COALESCE(receiving_rec.bill_number, 'N/A'),
                    DATE(receiving_rec.created_at),
                    COALESCE(received_by_user.username, 'Unknown User'),
                    TO_CHAR(current_user_deadline, 'YYYY-MM-DD HH24:MI:SS'));
                    
            ELSE
                task_title := 'New Delivery Arrived – Confirm Product is Placed';
                task_description := format('🧾 General Task

Confirm product placement for this receiving record.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Deadline: %s (24 hours from assignment)

Please confirm that products have been properly placed and organized.', 
                    COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                    COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                    receiving_rec.vendor_id,
                    receiving_rec.bill_amount,
                    COALESCE(receiving_rec.bill_number, 'N/A'),
                    DATE(receiving_rec.created_at),
                    COALESCE(received_by_user.username, 'Unknown User'),
                    TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                    
                notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: %s

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Deadline: %s (24 hours)

Please confirm product placement completion.', 
                    task_title,
                    COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                    COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                    receiving_rec.vendor_id,
                    receiving_rec.bill_amount,
                    COALESCE(receiving_rec.bill_number, 'N/A'),
                    DATE(receiving_rec.created_at),
                    COALESCE(received_by_user.username, 'Unknown User'),
                    TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
            END IF;
            
            -- Create task
            INSERT INTO tasks (
                title,
                description,
                status,
                priority,
                due_datetime,
                created_by,
                created_by_name,
                created_by_role,
                created_at
            ) VALUES (
                task_title,
                task_description,
                'pending',
                'high',
                current_user_deadline,  -- Use current_user_deadline instead of deadline_time
                generated_by_user_id,
                COALESCE(generated_by_name, 'System'),
                COALESCE(generated_by_role, 'Admin'),
                NOW()
            ) RETURNING id INTO new_task_id;
            
            -- ✅ FIXED: Create task assignment with proper deadline fields and require_task_finished
            INSERT INTO task_assignments (
                task_id,
                assignment_type,
                assigned_to_user_id,
                assigned_by,
                assigned_by_name,
                assigned_at,
                status,
                deadline_date,              -- ✅ ADDED: Extract date from deadline_datetime
                deadline_time,              -- ✅ ADDED: Extract time from deadline_datetime
                deadline_datetime,          -- Already present
                is_reassignable,
                require_task_finished,      -- ✅ CHANGED: true instead of false
                require_photo_upload,
                require_erp_reference
            ) VALUES (
                new_task_id,
                'individual',
                user_id,
                generated_by_user_id,
                COALESCE(generated_by_name, 'System'),
                NOW(),
                'pending',
                DATE(current_user_deadline),        -- ✅ ADDED: Extract date portion (24h or 72h based on role)
                (current_user_deadline AT TIME ZONE 'UTC')::TIME,  -- ✅ ADDED: Extract time portion
                current_user_deadline,  -- Use current_user_deadline (24h or 72h based on role)
                true,
                true,                       -- ✅ CHANGED: from false to true
                false,
                false
            );
            
            task_count := task_count + 1;
            
            -- Create notification with correct targeting
            INSERT INTO notifications (
                title,
                message,
                type,
                priority,
                target_type,
                target_users,
                created_by,
                created_by_name,
                created_by_role,
                task_id,
                created_at
            ) VALUES (
                'New Task Assigned',
                notification_message,
                'task_assignment',
                'medium',
                'specific_users',
                jsonb_build_array(user_id),
                COALESCE(generated_by_name, 'System'),
                COALESCE(generated_by_name, 'System'),
                COALESCE(generated_by_role, 'Admin'),
                new_task_id,
                NOW()
            ) RETURNING id INTO notification_id;
            
            notification_count := notification_count + 1;
        END IF;
    END LOOP;
    
    -- Build success response
    result := json_build_object(
        'success', true,
        'message', format('Successfully processed clearance certificate and created %s tasks with %s notifications', task_count, notification_count),
        'data', json_build_object(
            'receiving_record_id', receiving_record_id_param,
            'tasks_created', task_count,
            'notifications_sent', notification_count,
            'deadline', TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
            'certificate_url', clearance_certificate_url_param
        )
    );
    
    RETURN result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM,
            'error_code', SQLSTATE
        );
END;
$$;

-- Add comment explaining the fix
COMMENT ON FUNCTION process_clearance_certificate_generation IS 'Generates tasks and notifications when a clearance certificate is created. Fixed to properly set deadline_date, deadline_time, and require_task_finished=true for all task assignments. Purchasing Manager gets 72-hour deadline, all others get 24-hour deadline.';
