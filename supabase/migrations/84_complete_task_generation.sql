-- COMPLETE TASK GENERATION: Create tasks for all roles with assignments and notifications
-- This will create tasks for all assigned users and send notifications

-- First, we need an assign_task function if it doesn't exist
CREATE OR REPLACE FUNCTION assign_task_simple(
    task_id_param UUID,
    assigned_to_user_id_param UUID,
    assigned_by_param TEXT,
    assigned_by_name_param TEXT,
    deadline_datetime_param TIMESTAMPTZ,
    priority_param TEXT,
    notes_param TEXT
)
RETURNS UUID AS $$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO task_assignments (
        task_id,
        assignment_type,
        assigned_to_user_id,
        assigned_by,
        assigned_by_name,
        deadline_datetime,
        priority_override,
        notes,
        status
    ) VALUES (
        task_id_param,
        'user',
        assigned_to_user_id_param,
        assigned_by_param,
        assigned_by_name_param,
        deadline_datetime_param,
        priority_param,
        notes_param,
        'assigned'
    ) RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$ LANGUAGE plpgsql;

-- Create notification function if it doesn't exist
CREATE OR REPLACE FUNCTION create_notification_simple(
    title_param TEXT,
    message_param TEXT,
    created_by_param TEXT,
    created_by_name_param TEXT,
    target_user_id_param UUID,
    task_id_param UUID,
    assignment_id_param UUID
)
RETURNS UUID AS $$
DECLARE
    notification_id UUID;
BEGIN
    INSERT INTO notifications (
        title,
        message,
        created_by,
        created_by_name,
        target_type,
        target_users,
        type,
        priority,
        task_id,
        task_assignment_id
    ) VALUES (
        title_param,
        message_param,
        created_by_param,
        created_by_name_param,
        'specific_users',
        to_jsonb(ARRAY[target_user_id_param::TEXT]),
        'task',
        'high',
        task_id_param,
        assignment_id_param
    ) RETURNING id INTO notification_id;
    
    RETURN notification_id;
END;
$$ LANGUAGE plpgsql;

-- Update generate_clearance_certificate_tasks to create tasks for ALL roles
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
    notification_id UUID;
    deadline_datetime TIMESTAMPTZ;
    task_description TEXT;
    user_id UUID;
    total_tasks INTEGER := 0;
    total_notifications INTEGER := 0;
    created_task_ids UUID[] := '{}';
    created_assignment_ids UUID[] := '{}';
BEGIN
    deadline_datetime := now() + INTERVAL '24 hours';
    
    -- Get receiving record details
    SELECT * INTO receiving_record 
    FROM receiving_records 
    WHERE id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving record not found: %', receiving_record_id_param;
    END IF;
    
    -- Get vendor details for description
    SELECT vendor_name INTO vendor_record 
    FROM vendors 
    WHERE erp_vendor_id = receiving_record.vendor_id;
    
    task_description := format('Vendor: %s, Bill #: %s, Bill Amount: %s, Bill Date: %s, Received by: %s',
        COALESCE(vendor_record.vendor_name, 'Unknown Vendor'),
        COALESCE(receiving_record.bill_number, 'N/A'),
        COALESCE(receiving_record.bill_amount::TEXT, 'N/A'),
        receiving_record.bill_date::TEXT,
        COALESCE(created_by_name, 'Unknown User')
    );
    
    -- 1. Branch Manager Task
    IF receiving_record.branch_manager_user_id IS NOT NULL THEN
        task_id := create_task(
            'New delivery arrived—start placing.',
            task_description,
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
            true    -- can_reassign
        );
        
        assignment_id := assign_task_simple(
            task_id,
            receiving_record.branch_manager_user_id,
            created_by_user_id,
            COALESCE(created_by_name, ''),
            deadline_datetime,
            'high',
            'Clearance certificate attached'
        );
        
        notification_id := create_notification_simple(
            'New Delivery Task Assigned',
            format('You have been assigned a new delivery task: %s', task_description),
            created_by_user_id,
            COALESCE(created_by_name, ''),
            receiving_record.branch_manager_user_id,
            task_id,
            assignment_id
        );
        
        total_tasks := total_tasks + 1;
        total_notifications := total_notifications + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
        
        RAISE NOTICE 'Branch Manager task created: %', task_id;
    END IF;
    
    -- 2. Purchase Manager Task
    IF receiving_record.purchasing_manager_user_id IS NOT NULL THEN
        task_id := create_task(
            'New delivery arrived—price check.',
            task_description,
            created_by_user_id,
            COALESCE(created_by_name, ''),
            COALESCE(created_by_role, ''),
            'medium',
            deadline_datetime::DATE,
            deadline_datetime::TIME,
            true,   -- require_task_finished
            false,  -- require_photo_upload  
            false,  -- require_erp_reference (NO ERP!)
            false,  -- can_escalate
            false   -- can_reassign
        );
        
        assignment_id := assign_task_simple(
            task_id,
            receiving_record.purchasing_manager_user_id,
            created_by_user_id,
            COALESCE(created_by_name, ''),
            deadline_datetime,
            'medium',
            'Clearance certificate attached'
        );
        
        notification_id := create_notification_simple(
            'Price Check Task Assigned',
            format('You have been assigned a price check task: %s', task_description),
            created_by_user_id,
            COALESCE(created_by_name, ''),
            receiving_record.purchasing_manager_user_id,
            task_id,
            assignment_id
        );
        
        total_tasks := total_tasks + 1;
        total_notifications := total_notifications + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
        
        RAISE NOTICE 'Purchase Manager task created: %', task_id;
    END IF;
    
    -- 3. Inventory Manager Task (NO ERP!)
    IF receiving_record.inventory_manager_user_id IS NOT NULL THEN
        task_id := create_task(
            'New delivery arrived—enter into the purchase ERP, upload the original bill, and update the ERP purchase invoice number.',
            task_description,
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
        
        assignment_id := assign_task_simple(
            task_id,
            receiving_record.inventory_manager_user_id,
            created_by_user_id,
            COALESCE(created_by_name, ''),
            deadline_datetime,
            'high',
            'Clearance certificate attached. NO ERP reference required.'
        );
        
        notification_id := create_notification_simple(
            'ERP Entry Task Assigned (No ERP Required)',
            format('You have been assigned an ERP entry task: %s', task_description),
            created_by_user_id,
            COALESCE(created_by_name, ''),
            receiving_record.inventory_manager_user_id,
            task_id,
            assignment_id
        );
        
        total_tasks := total_tasks + 1;
        total_notifications := total_notifications + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
        
        RAISE NOTICE 'Inventory Manager task created: %', task_id;
    END IF;
    
    -- 4. Night Supervisors Tasks
    IF receiving_record.night_supervisor_user_ids IS NOT NULL AND array_length(receiving_record.night_supervisor_user_ids, 1) > 0 THEN
        FOREACH user_id IN ARRAY receiving_record.night_supervisor_user_ids
        LOOP
            task_id := create_task(
                'New delivery arrived—confirm product is placed.',
                task_description,
                created_by_user_id,
                COALESCE(created_by_name, ''),
                COALESCE(created_by_role, ''),
                'medium',
                deadline_datetime::DATE,
                deadline_datetime::TIME,
                true,   -- require_task_finished
                false,  -- require_photo_upload  
                false,  -- require_erp_reference (NO ERP!)
                false,  -- can_escalate
                true    -- can_reassign
            );
            
            assignment_id := assign_task_simple(
                task_id,
                user_id,
                created_by_user_id,
                COALESCE(created_by_name, ''),
                deadline_datetime,
                'medium',
                'Clearance certificate attached'
            );
            
            notification_id := create_notification_simple(
                'Product Placement Task Assigned',
                format('You have been assigned a product placement task: %s', task_description),
                created_by_user_id,
                COALESCE(created_by_name, ''),
                user_id,
                task_id,
                assignment_id
            );
            
            total_tasks := total_tasks + 1;
            total_notifications := total_notifications + 1;
            created_task_ids := created_task_ids || task_id;
            created_assignment_ids := created_assignment_ids || assignment_id;
        END LOOP;
        
        RAISE NOTICE 'Night Supervisor tasks created: %', array_length(receiving_record.night_supervisor_user_ids, 1);
    END IF;
    
    -- 5. Warehouse Handlers Tasks
    IF receiving_record.warehouse_handler_user_ids IS NOT NULL AND array_length(receiving_record.warehouse_handler_user_ids, 1) > 0 THEN
        FOREACH user_id IN ARRAY receiving_record.warehouse_handler_user_ids
        LOOP
            task_id := create_task(
                'New delivery arrived—confirm product is moved to display.',
                task_description,
                created_by_user_id,
                COALESCE(created_by_name, ''),
                COALESCE(created_by_role, ''),
                'medium',
                deadline_datetime::DATE,
                deadline_datetime::TIME,
                true,   -- require_task_finished
                false,  -- require_photo_upload  
                false,  -- require_erp_reference (NO ERP!)
                false,  -- can_escalate
                false   -- can_reassign
            );
            
            assignment_id := assign_task_simple(
                task_id,
                user_id,
                created_by_user_id,
                COALESCE(created_by_name, ''),
                deadline_datetime,
                'medium',
                'Clearance certificate attached'
            );
            
            notification_id := create_notification_simple(
                'Display Movement Task Assigned',
                format('You have been assigned a display movement task: %s', task_description),
                created_by_user_id,
                COALESCE(created_by_name, ''),
                user_id,
                task_id,
                assignment_id
            );
            
            total_tasks := total_tasks + 1;
            total_notifications := total_notifications + 1;
            created_task_ids := created_task_ids || task_id;
            created_assignment_ids := created_assignment_ids || assignment_id;
        END LOOP;
        
        RAISE NOTICE 'Warehouse Handler tasks created: %', array_length(receiving_record.warehouse_handler_user_ids, 1);
    END IF;
    
    -- 6. Shelf Stockers Tasks
    IF receiving_record.shelf_stocker_user_ids IS NOT NULL AND array_length(receiving_record.shelf_stocker_user_ids, 1) > 0 THEN
        FOREACH user_id IN ARRAY receiving_record.shelf_stocker_user_ids
        LOOP
            task_id := create_task(
                'New delivery arrived—confirm product is placed.',
                task_description,
                created_by_user_id,
                COALESCE(created_by_name, ''),
                COALESCE(created_by_role, ''),
                'low',
                deadline_datetime::DATE,
                deadline_datetime::TIME,
                true,   -- require_task_finished
                false,  -- require_photo_upload  
                false,  -- require_erp_reference (NO ERP!)
                false,  -- can_escalate
                false   -- can_reassign
            );
            
            assignment_id := assign_task_simple(
                task_id,
                user_id,
                created_by_user_id,
                COALESCE(created_by_name, ''),
                deadline_datetime,
                'low',
                'Confirm product placement on shelves'
            );
            
            notification_id := create_notification_simple(
                'Shelf Stocking Task Assigned',
                format('You have been assigned a shelf stocking task: %s', task_description),
                created_by_user_id,
                COALESCE(created_by_name, ''),
                user_id,
                task_id,
                assignment_id
            );
            
            total_tasks := total_tasks + 1;
            total_notifications := total_notifications + 1;
            created_task_ids := created_task_ids || task_id;
            created_assignment_ids := created_assignment_ids || assignment_id;
        END LOOP;
        
        RAISE NOTICE 'Shelf Stocker tasks created: %', array_length(receiving_record.shelf_stocker_user_ids, 1);
    END IF;
    
    -- 7. Accountant Task (NO ERP!)
    IF receiving_record.accountant_user_id IS NOT NULL THEN
        task_id := create_task(
            'New delivery arrived—confirm the original has been received and filed, and verify the ERP purchase invoice number with the original entry.',
            task_description,
            created_by_user_id,
            COALESCE(created_by_name, ''),
            COALESCE(created_by_role, ''),
            'medium',
            deadline_datetime::DATE,
            deadline_datetime::TIME,
            true,   -- require_task_finished
            false,  -- require_photo_upload  
            false,  -- require_erp_reference (NO ERP!)
            false,  -- can_escalate
            false   -- can_reassign
        );
        
        assignment_id := assign_task_simple(
            task_id,
            receiving_record.accountant_user_id,
            created_by_user_id,
            COALESCE(created_by_name, ''),
            deadline_datetime,
            'medium',
            'NO ERP reference required'
        );
        
        notification_id := create_notification_simple(
            'Accounting Filing Task Assigned',
            format('You have been assigned an accounting filing task: %s', task_description),
            created_by_user_id,
            COALESCE(created_by_name, ''),
            receiving_record.accountant_user_id,
            task_id,
            assignment_id
        );
        
        total_tasks := total_tasks + 1;
        total_notifications := total_notifications + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
        
        RAISE NOTICE 'Accountant task created: %', task_id;
    END IF;
    
    RAISE NOTICE 'Total tasks created: %, Total notifications sent: %', total_tasks, total_notifications;
    
    RETURN QUERY SELECT total_tasks, total_notifications, created_task_ids, created_assignment_ids;
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error in generate_clearance_certificate_tasks: %', SQLERRM;
    RAISE;
END;
$$ LANGUAGE plpgsql;