-- Migration: Fix receiving task assignment deadline
-- File: 75_fix_receiving_task_deadline.sql
-- Description: Updates process_clearance_certificate_generation function to set deadline columns in task_assignments table

BEGIN;

-- Drop existing function
DROP FUNCTION IF EXISTS process_clearance_certificate_generation(uuid, text, uuid, text, text);

-- Recreate function with deadline columns
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
                    task_description := format('🧾 Task for Accountant

File and archive the original bill for this receiving record.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours from assignment)
Certificate URL: %s

You are required to complete this task within the next 24 hours.
Once done, confirm completion in the system to close the task.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
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
                    task_description := format('🧾 Task for Branch Manager

Manage the delivery placement process for this receiving record.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
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
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'));
                ELSIF user_id = receiving_rec.purchasing_manager_user_id THEN
                    task_title := 'New Delivery Arrived – Price Check';
                    task_description := format('🧾 Task for Purchasing Manager

Verify and confirm the pricing details for this receiving record.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours from assignment)

Ensure all product prices match the purchase order and supplier invoice.
Report any discrepancies immediately and update the system once verification is completed.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
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
                    task_description := format('🧾 Task for Inventory Manager

Process the new delivery in the ERP system and upload the original bill for this receiving record.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours from assignment)

Ensure all items are entered accurately into the purchase ERP.
Upload the scanned original bill and verify all quantities and pricing before confirming completion in the system.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
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
                    task_description := format('🧾 Task for Shelf Stocker

Confirm that all products from this new delivery have been properly placed on the shelves.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours from assignment)

Ensure that every product from this delivery is displayed correctly, barcodes are visible, and shelf tags are updated if needed.
Once completed, mark the task as finished in the system.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
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
                    task_description := format('🧾 Task for Night Supervisor

Supervise and confirm that all products from this delivery have been properly placed during the night shift.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours from assignment)

Ensure that all products are unloaded, organized, and placed correctly on shelves or designated areas.
Report any discrepancies or delays immediately and mark the task as completed once the process is verified.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
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
                    task_description := format('🧾 Task for Warehouse Handler

Handle and confirm that all products from this receiving record have been moved from the warehouse to the display area.

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours from assignment)

Ensure that products are correctly transferred to the sales floor or designated display section without damage or delay.
Once all items are placed, confirm completion in the system and report any storage or stock discrepancies.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
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
                
                -- Create task assignment with deadline columns
                INSERT INTO task_assignments (
                    task_id,
                    assignment_type,
                    assigned_to_user_id,
                    assigned_to_branch_id,
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
                    receiving_rec.branch_id,
                    generated_by_user_id::text,
                    NOW(),
                    deadline_time,
                    deadline_time::date,
                    deadline_time::time,
                    'assigned'
                );
                
                task_count := task_count + 1;
                
                -- Create detailed notification message based on user role
                IF user_id = receiving_rec.accountant_user_id THEN
                    notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: Filing Original Bill Task

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)

Task Details:
Please file and archive the original bill for receiving record %s.
Certificate Link: %s', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
                        receiving_rec.id,
                        clearance_certificate_url_param);
                ELSIF user_id = receiving_rec.branch_manager_user_id THEN
                    notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: New Delivery Arrived – Start Placing

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)

Task Details:
Please manage the placement of the new delivery for receiving record %s.
Confirm once all products have been properly placed on the shelves.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
                        receiving_rec.id);
                ELSIF user_id = receiving_rec.purchasing_manager_user_id THEN
                    notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: New Delivery Arrived – Price Check

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)

Task Details:
Please verify pricing for receiving record %s.
Confirm once all price checks are completed and approved in the system.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
                        receiving_rec.id);
                ELSIF user_id = receiving_rec.inventory_manager_user_id THEN
                    notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)

Task Details:
Please process inventory for receiving record %s.
Enter all items into the ERP, upload the original bill, and confirm completion once done.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
                        receiving_rec.id);
                ELSIF user_id = ANY(receiving_rec.shelf_stocker_user_ids) THEN
                    notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: New Delivery Arrived – Confirm Product is Placed

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)

Task Details:
Please confirm that products for receiving record %s have been placed correctly on the shelves.
Once placement is complete, update the system to mark the task as done.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
                        receiving_rec.id);
                ELSIF user_id = ANY(receiving_rec.night_supervisor_user_ids) THEN
                    notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: New Delivery Arrived – Confirm Product is Placed

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)

Task Details:
Please supervise the night placement for receiving record %s.
Ensure all products have been properly placed and verified, then confirm completion in the system.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
                        receiving_rec.id);
                ELSIF user_id = ANY(receiving_rec.warehouse_handler_user_ids) THEN
                    notification_message := format('🔔 New Task Assigned

A new task has been assigned to you: New Delivery Arrived – Confirm Product is Moved to Display

Branch: %s
Vendor: %s (ID: %s)
Bill Amount: %s
Bill Number: %s
Received Date: %s
Received By: %s
Received Time: %s
Deadline: %s (24 hours)

Task Details:
Please handle and confirm that products for receiving record %s have been moved from the warehouse to the display area.
Once the movement is complete, update the system to mark the task as done.', 
                        COALESCE((SELECT name_en FROM branches WHERE id = receiving_rec.branch_id), 'N/A'),
                        COALESCE(vendor_rec.vendor_name, 'Unknown Vendor'),
                        receiving_rec.vendor_id,
                        receiving_rec.bill_amount,
                        COALESCE(receiving_rec.bill_number, 'N/A'),
                        DATE(receiving_rec.created_at),
                        COALESCE(received_by_user.username, 'Unknown User'),
                        TO_CHAR(receiving_rec.created_at, 'HH24:MI:SS'),
                        TO_CHAR(deadline_time, 'YYYY-MM-DD HH24:MI:SS'),
                        receiving_rec.id);
                ELSE
                    -- Default notification for other roles
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
                END IF;
                
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

COMMIT;
