-- Copy this SQL and paste it into the Supabase SQL Editor to fix the create_task function calls

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
    -- 1. Branch Manager Task
    -- =============================================
    IF receiving_record.branch_manager_user_id IS NOT NULL THEN
        -- Create task
        SELECT create_task(
            'New Delivery Arrived – Start Placing',
            task_description,
            created_by_user_id,
            created_by_name,
            created_by_role,
            'high',
            'receiving_delivery',
            (deadline_datetime)::DATE,
            (deadline_datetime)::TIME,
            true,
            false,
            false,
            false,
            true,
            NULL::INTERVAL,
            NULL::BIGINT,
            receiving_record.branch_id,
            NULL::UUID,
            NULL::UUID,
            ARRAY['delivery', 'branch_management'],
            jsonb_build_object(
                'receiving_record_id', receiving_record_id_param,
                'role_type', 'branch_manager',
                'clearance_certificate_url', clearance_certificate_url_param
            ),
            false
        ) INTO task_id;
        
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
            (deadline_datetime)::DATE,
            (deadline_datetime)::TIME,
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
    
    -- =============================================
    -- 2. Purchase Manager Task
    -- =============================================
    IF receiving_record.purchasing_manager_user_id IS NOT NULL THEN
        SELECT create_task(
            'New Delivery Arrived – Price Check',
            task_description,
            created_by_user_id,
            created_by_name,
            created_by_role,
            'medium',
            'receiving_delivery',
            (deadline_datetime)::DATE,
            (deadline_datetime)::TIME,
            true,
            false,
            false,
            false,
            false,
            NULL::INTERVAL,
            NULL::BIGINT,
            receiving_record.branch_id,
            NULL::UUID,
            NULL::UUID,
            ARRAY['delivery', 'price_check'],
            jsonb_build_object(
                'receiving_record_id', receiving_record_id_param,
                'role_type', 'purchase_manager',
                'clearance_certificate_url', clearance_certificate_url_param
            ),
            false
        ) INTO task_id;
        
        SELECT assign_task(
            task_id, 'primary', receiving_record.purchasing_manager_user_id::TEXT, NULL,
            created_by_user_id, created_by_name, NULL, NULL,
            (deadline_datetime)::DATE, (deadline_datetime)::TIME,
            'medium', 'Clearance certificate attached', false, false,
            jsonb_build_object('clearance_certificate_url', clearance_certificate_url_param)
        ) INTO assignment_id;
        
        INSERT INTO receiving_tasks (
            receiving_record_id, task_id, assignment_id, role_type,
            assigned_user_id, clearance_certificate_url
        ) VALUES (
            receiving_record_id_param, task_id, assignment_id, 'purchase_manager',
            receiving_record.purchasing_manager_user_id, clearance_certificate_url_param
        );
        
        total_tasks := total_tasks + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
        
        INSERT INTO notifications (
            title, message, created_by, created_by_name, created_by_role,
            target_type, target_users, type, priority,
            task_id, task_assignment_id, has_attachments, metadata
        ) VALUES (
            'Price Check Task Assigned',
            format('You have been assigned a price check task: %s', task_description),
            created_by_user_id, created_by_name, created_by_role,
            'specific_users', to_jsonb(ARRAY[receiving_record.purchasing_manager_user_id::TEXT]),
            'task', 'medium', task_id, assignment_id, true,
            jsonb_build_object(
                'receiving_record_id', receiving_record_id_param,
                'clearance_certificate_url', clearance_certificate_url_param
            )
        );
        
        total_notifications := total_notifications + 1;
    END IF;
    
    -- =============================================
    -- 3. Inventory Manager Task
    -- =============================================
    IF receiving_record.inventory_manager_user_id IS NOT NULL THEN
        SELECT create_task(
            'New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill',
            task_description,
            created_by_user_id,
            created_by_name,
            created_by_role,
            'high',
            'receiving_delivery',
            (deadline_datetime)::DATE,
            (deadline_datetime)::TIME,
            true,
            false,
            true,
            false,
            false,
            NULL::INTERVAL,
            NULL::BIGINT,
            receiving_record.branch_id,
            NULL::UUID,
            NULL::UUID,
            ARRAY['delivery', 'erp_entry', 'original_bill'],
            jsonb_build_object(
                'receiving_record_id', receiving_record_id_param,
                'role_type', 'inventory_manager',
                'clearance_certificate_url', clearance_certificate_url_param
            ),
            false
        ) INTO task_id;
        
        SELECT assign_task(
            task_id, 'primary', receiving_record.inventory_manager_user_id::TEXT, NULL,
            created_by_user_id, created_by_name, NULL, NULL,
            (deadline_datetime)::DATE, (deadline_datetime)::TIME,
            'high', 'Clearance certificate attached. ERP reference and original bill upload required.',
            false, true, -- require_erp_reference = true
            jsonb_build_object('clearance_certificate_url', clearance_certificate_url_param)
        ) INTO assignment_id;
        
        INSERT INTO receiving_tasks (
            receiving_record_id, task_id, assignment_id, role_type,
            assigned_user_id, requires_erp_reference, requires_original_bill_upload,
            clearance_certificate_url
        ) VALUES (
            receiving_record_id_param, task_id, assignment_id, 'inventory_manager',
            receiving_record.inventory_manager_user_id, true, true, clearance_certificate_url_param
        );
        
        total_tasks := total_tasks + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
        
        INSERT INTO notifications (
            title, message, created_by, created_by_name, created_by_role,
            target_type, target_users, type, priority,
            task_id, task_assignment_id, has_attachments, metadata
        ) VALUES (
            'ERP Entry and Bill Upload Task Assigned',
            format('You have been assigned an ERP entry task with original bill upload requirement: %s', task_description),
            created_by_user_id, created_by_name, created_by_role,
            'specific_users', to_jsonb(ARRAY[receiving_record.inventory_manager_user_id::TEXT]),
            'task', 'high', task_id, assignment_id, true,
            jsonb_build_object(
                'receiving_record_id', receiving_record_id_param,
                'clearance_certificate_url', clearance_certificate_url_param
            )
        );
        
        total_notifications := total_notifications + 1;
    END IF;
    
    -- =============================================
    -- 4. Night Supervisor Tasks
    -- =============================================
    IF receiving_record.night_supervisor_user_ids IS NOT NULL AND array_length(receiving_record.night_supervisor_user_ids, 1) > 0 THEN
        FOREACH user_id IN ARRAY receiving_record.night_supervisor_user_ids
        LOOP
            SELECT create_task(
                'New Delivery Arrived – Confirm Product is Placed',
                task_description,
                created_by_user_id,
                created_by_name,
                created_by_role,
                'medium',
                'receiving_delivery',
                (deadline_datetime)::DATE,
                (deadline_datetime)::TIME,
                true,
                false,
                false,
                false,
                true,
                NULL::INTERVAL,
                NULL::BIGINT,
                receiving_record.branch_id,
                NULL::UUID,
                NULL::UUID,
                ARRAY['delivery', 'product_placement'],
                jsonb_build_object(
                    'receiving_record_id', receiving_record_id_param,
                    'role_type', 'night_supervisor',
                    'clearance_certificate_url', clearance_certificate_url_param
                ),
                false
            ) INTO task_id;
            
            SELECT assign_task(
                task_id, 'primary', user_id::TEXT, NULL,
                created_by_user_id, created_by_name, NULL, NULL,
                (deadline_datetime)::DATE, (deadline_datetime)::TIME,
                'medium', 'Clearance certificate attached', false, false,
                jsonb_build_object('clearance_certificate_url', clearance_certificate_url_param)
            ) INTO assignment_id;
            
            INSERT INTO receiving_tasks (
                receiving_record_id, task_id, assignment_id, role_type,
                assigned_user_id, requires_reassignment, clearance_certificate_url
            ) VALUES (
                receiving_record_id_param, task_id, assignment_id, 'night_supervisor',
                user_id, true, clearance_certificate_url_param
            );
            
            total_tasks := total_tasks + 1;
            created_task_ids := created_task_ids || task_id;
            created_assignment_ids := created_assignment_ids || assignment_id;
        END LOOP;
        
        -- Create single notification for all night supervisors
        user_ids := ARRAY(SELECT unnest(receiving_record.night_supervisor_user_ids)::TEXT);
        INSERT INTO notifications (
            title, message, created_by, created_by_name, created_by_role,
            target_type, target_users, type, priority,
            task_id, has_attachments, metadata
        ) VALUES (
            'Product Placement Task Assigned',
            format('You have been assigned a product placement confirmation task: %s', task_description),
            created_by_user_id, created_by_name, created_by_role,
            'specific_users', to_jsonb(user_ids),
            'task', 'medium', task_id, true,
            jsonb_build_object(
                'receiving_record_id', receiving_record_id_param,
                'clearance_certificate_url', clearance_certificate_url_param
            )
        );
        
        total_notifications := total_notifications + 1;
    END IF;
    
    -- =============================================
    -- 5. Warehouse and Stock Handler Tasks
    -- =============================================
    IF receiving_record.warehouse_handler_user_ids IS NOT NULL AND array_length(receiving_record.warehouse_handler_user_ids, 1) > 0 THEN
        FOREACH user_id IN ARRAY receiving_record.warehouse_handler_user_ids
        LOOP
            SELECT create_task(
                'New Delivery Arrived – Confirm Product is Moved to Display',
                task_description,
                created_by_user_id,
                created_by_name,
                created_by_role,
                'medium',
                'receiving_delivery',
                (deadline_datetime)::DATE,
                (deadline_datetime)::TIME,
                true,
                false,
                false,
                false,
                false,
                NULL::INTERVAL,
                NULL::BIGINT,
                receiving_record.branch_id,
                NULL::UUID,
                NULL::UUID,
                ARRAY['delivery', 'display_movement'],
                jsonb_build_object(
                    'receiving_record_id', receiving_record_id_param,
                    'role_type', 'warehouse_handler',
                    'clearance_certificate_url', clearance_certificate_url_param
                ),
                false
            ) INTO task_id;
            
            SELECT assign_task(
                task_id, 'primary', user_id::TEXT, NULL,
                created_by_user_id, created_by_name, NULL, NULL,
                (deadline_datetime)::DATE, (deadline_datetime)::TIME,
                'medium', 'Clearance certificate attached', false, false,
                jsonb_build_object('clearance_certificate_url', clearance_certificate_url_param)
            ) INTO assignment_id;
            
            INSERT INTO receiving_tasks (
                receiving_record_id, task_id, assignment_id, role_type,
                assigned_user_id, clearance_certificate_url
            ) VALUES (
                receiving_record_id_param, task_id, assignment_id, 'warehouse_handler',
                user_id, clearance_certificate_url_param
            );
            
            total_tasks := total_tasks + 1;
            created_task_ids := created_task_ids || task_id;
            created_assignment_ids := created_assignment_ids || assignment_id;
        END LOOP;
        
        -- Create notification for all warehouse handlers
        user_ids := ARRAY(SELECT unnest(receiving_record.warehouse_handler_user_ids)::TEXT);
        INSERT INTO notifications (
            title, message, created_by, created_by_name, created_by_role,
            target_type, target_users, type, priority,
            has_attachments, metadata
        ) VALUES (
            'Display Movement Task Assigned',
            format('You have been assigned a display movement task: %s', task_description),
            created_by_user_id, created_by_name, created_by_role,
            'specific_users', to_jsonb(user_ids),
            'task', 'medium', true,
            jsonb_build_object(
                'receiving_record_id', receiving_record_id_param,
                'clearance_certificate_url', clearance_certificate_url_param
            )
        );
        
        total_notifications := total_notifications + 1;
    END IF;
    
    -- =============================================
    -- 6. Shelf Stocker Tasks
    -- =============================================
    IF receiving_record.shelf_stocker_user_ids IS NOT NULL AND array_length(receiving_record.shelf_stocker_user_ids, 1) > 0 THEN
        FOREACH user_id IN ARRAY receiving_record.shelf_stocker_user_ids
        LOOP
            SELECT create_task(
                'New Delivery Arrived – Confirm Product is Placed',
                format('Vendor: %s, Bill Date: %s, Review User: %s',
                    COALESCE(vendor_record.vendor_name, 'Unknown Vendor'),
                    receiving_record.bill_date::TEXT,
                    COALESCE(created_by_name, 'Unknown User')
                ),
                created_by_user_id,
                created_by_name,
                created_by_role,
                'low',
                'receiving_delivery',
                (deadline_datetime)::DATE,
                (deadline_datetime)::TIME,
                true,
                false,
                false,
                false,
                false,
                NULL::INTERVAL,
                NULL::BIGINT,
                receiving_record.branch_id,
                NULL::UUID,
                NULL::UUID,
                ARRAY['delivery', 'shelf_stocking'],
                jsonb_build_object(
                    'receiving_record_id', receiving_record_id_param,
                    'role_type', 'shelf_stocker'
                ),
                false
            ) INTO task_id;
            
            SELECT assign_task(
                task_id, 'primary', user_id::TEXT, NULL,
                created_by_user_id, created_by_name, NULL, NULL,
                (deadline_datetime)::DATE, (deadline_datetime)::TIME,
                'low', 'Confirm product placement on shelves', false, false,
                '{}'::jsonb
            ) INTO assignment_id;
            
            INSERT INTO receiving_tasks (
                receiving_record_id, task_id, assignment_id, role_type,
                assigned_user_id, clearance_certificate_url
            ) VALUES (
                receiving_record_id_param, task_id, assignment_id, 'shelf_stocker',
                user_id, NULL -- No clearance certificate for shelf stockers
            );
            
            total_tasks := total_tasks + 1;
            created_task_ids := created_task_ids || task_id;
            created_assignment_ids := created_assignment_ids || assignment_id;
        END LOOP;
        
        -- Create notification for all shelf stockers
        user_ids := ARRAY(SELECT unnest(receiving_record.shelf_stocker_user_ids)::TEXT);
        INSERT INTO notifications (
            title, message, created_by, created_by_name, created_by_role,
            target_type, target_users, type, priority,
            metadata
        ) VALUES (
            'Shelf Stocking Task Assigned',
            format('You have been assigned a shelf stocking task: %s', task_description),
            created_by_user_id, created_by_name, created_by_role,
            'specific_users', to_jsonb(user_ids),
            'task', 'low',
            jsonb_build_object('receiving_record_id', receiving_record_id_param)
        );
        
        total_notifications := total_notifications + 1;
    END IF;
    
    -- =============================================
    -- 7. Accountant Task
    -- =============================================
    IF receiving_record.accountant_user_id IS NOT NULL THEN
        SELECT create_task(
            'New Delivery Arrived – Confirm Original Has Been Received and Filed',
            format('Vendor: %s, Bill Date: %s, Review User: %s',
                COALESCE(vendor_record.vendor_name, 'Unknown Vendor'),
                receiving_record.bill_date::TEXT,
                COALESCE(created_by_name, 'Unknown User')
            ),
            created_by_user_id,
            created_by_name,
            created_by_role,
            'medium',
            'receiving_delivery',
            (deadline_datetime)::DATE,
            (deadline_datetime)::TIME,
            true,
            false,
            true,
            false,
            false,
            NULL::INTERVAL,
            NULL::BIGINT,
            receiving_record.branch_id,
            NULL::UUID,
            NULL::UUID,
            ARRAY['delivery', 'accounting', 'filing'],
            jsonb_build_object(
                'receiving_record_id', receiving_record_id_param,
                'role_type', 'accountant'
            ),
            false
        ) INTO task_id;
        
        SELECT assign_task(
            task_id, 'primary', receiving_record.accountant_user_id::TEXT, NULL,
            created_by_user_id, created_by_name, NULL, NULL,
            (deadline_datetime)::DATE, (deadline_datetime)::TIME,
            'medium', 'ERP reference number required', false, true,
            '{}'::jsonb
        ) INTO assignment_id;
        
        INSERT INTO receiving_tasks (
            receiving_record_id, task_id, assignment_id, role_type,
            assigned_user_id, requires_erp_reference, clearance_certificate_url
        ) VALUES (
            receiving_record_id_param, task_id, assignment_id, 'accountant',
            receiving_record.accountant_user_id, true, NULL
        );
        
        total_tasks := total_tasks + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
        
        INSERT INTO notifications (
            title, message, created_by, created_by_name, created_by_role,
            target_type, target_users, type, priority,
            task_id, task_assignment_id, metadata
        ) VALUES (
            'Accounting Filing Task Assigned',
            format('You have been assigned an accounting filing task: %s', task_description),
            created_by_user_id, created_by_name, created_by_role,
            'specific_users', to_jsonb(ARRAY[receiving_record.accountant_user_id::TEXT]),
            'task', 'medium', task_id, assignment_id,
            jsonb_build_object('receiving_record_id', receiving_record_id_param)
        );
        
        total_notifications := total_notifications + 1;
    END IF;
    
    -- Return results
    RETURN QUERY SELECT 
        total_tasks,
        total_notifications,
        created_task_ids,
        created_assignment_ids;
END;
$$ LANGUAGE plpgsql;