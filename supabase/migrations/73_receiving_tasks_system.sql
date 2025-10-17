-- =============================================
-- Receiving Tasks System for Clearance Certificate Process
-- This migration creates a system to automatically generate role-specific tasks
-- when "Generate Clearance Certificate" is pressed from the receiving process
-- =============================================

-- Create receiving_tasks table to track tasks created from receiving records
CREATE TABLE IF NOT EXISTS public.receiving_tasks (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    receiving_record_id UUID NOT NULL REFERENCES receiving_records(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    assignment_id UUID NOT NULL REFERENCES task_assignments(id) ON DELETE CASCADE,
    
    -- Role-specific task information
    role_type VARCHAR(50) NOT NULL,
    assigned_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    
    -- Task requirements based on role
    requires_erp_reference BOOLEAN DEFAULT false,
    requires_original_bill_upload BOOLEAN DEFAULT false,
    requires_reassignment BOOLEAN DEFAULT false,
    requires_task_finished_mark BOOLEAN DEFAULT true,
    
    -- Completion tracking
    erp_reference_number VARCHAR(255),
    original_bill_uploaded BOOLEAN DEFAULT false,
    original_bill_file_path TEXT,
    task_completed BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ,
    
    -- Metadata
    clearance_certificate_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    CONSTRAINT receiving_tasks_pkey PRIMARY KEY (id),
    CONSTRAINT receiving_tasks_role_type_check CHECK (role_type IN (
        'branch_manager', 'purchase_manager', 'inventory_manager', 
        'night_supervisor', 'warehouse_handler', 'shelf_stocker', 'accountant'
    ))
) TABLESPACE pg_default;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_receiving_record_id 
ON public.receiving_tasks (receiving_record_id);

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_task_id 
ON public.receiving_tasks (task_id);

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_assignment_id 
ON public.receiving_tasks (assignment_id);

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_assigned_user_id 
ON public.receiving_tasks (assigned_user_id);

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_role_type 
ON public.receiving_tasks (role_type);

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_task_completed 
ON public.receiving_tasks (task_completed);

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_created_at 
ON public.receiving_tasks (created_at DESC);

-- Create composite indexes
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_user_role 
ON public.receiving_tasks (assigned_user_id, role_type);

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_record_role 
ON public.receiving_tasks (receiving_record_id, role_type);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_receiving_tasks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_receiving_tasks_updated_at ON receiving_tasks;
CREATE TRIGGER trigger_update_receiving_tasks_updated_at 
BEFORE UPDATE ON receiving_tasks 
FOR EACH ROW 
EXECUTE FUNCTION update_receiving_tasks_updated_at();

-- Add table comments
COMMENT ON TABLE public.receiving_tasks IS 'Tracks tasks created from receiving records for clearance certificate process';
COMMENT ON COLUMN public.receiving_tasks.receiving_record_id IS 'Reference to the original receiving record';
COMMENT ON COLUMN public.receiving_tasks.task_id IS 'Reference to the generated task';
COMMENT ON COLUMN public.receiving_tasks.assignment_id IS 'Reference to the task assignment';
COMMENT ON COLUMN public.receiving_tasks.role_type IS 'Type of role this task was created for';
COMMENT ON COLUMN public.receiving_tasks.assigned_user_id IS 'User assigned to this task';
COMMENT ON COLUMN public.receiving_tasks.requires_erp_reference IS 'Whether this task requires ERP reference number';
COMMENT ON COLUMN public.receiving_tasks.requires_original_bill_upload IS 'Whether this task requires original bill upload';
COMMENT ON COLUMN public.receiving_tasks.requires_reassignment IS 'Whether this task can be reassigned';
COMMENT ON COLUMN public.receiving_tasks.erp_reference_number IS 'ERP reference number entered by user';
COMMENT ON COLUMN public.receiving_tasks.original_bill_uploaded IS 'Whether original bill has been uploaded';
COMMENT ON COLUMN public.receiving_tasks.clearance_certificate_url IS 'URL to the generated clearance certificate';

-- =============================================
-- Function to generate clearance certificate tasks
-- =============================================

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

-- =============================================
-- Function to update receiving task completion
-- =============================================

CREATE OR REPLACE FUNCTION update_receiving_task_completion(
    receiving_task_id_param UUID,
    erp_reference_param VARCHAR DEFAULT NULL,
    original_bill_uploaded_param BOOLEAN DEFAULT NULL,
    original_bill_file_path_param TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    receiving_task RECORD;
    can_complete BOOLEAN := true;
BEGIN
    -- Get receiving task details
    SELECT * INTO receiving_task 
    FROM receiving_tasks 
    WHERE id = receiving_task_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving task not found: %', receiving_task_id_param;
    END IF;
    
    -- Update the receiving task
    UPDATE receiving_tasks 
    SET 
        erp_reference_number = COALESCE(erp_reference_param, erp_reference_number),
        original_bill_uploaded = COALESCE(original_bill_uploaded_param, original_bill_uploaded),
        original_bill_file_path = COALESCE(original_bill_file_path_param, original_bill_file_path),
        updated_at = now()
    WHERE id = receiving_task_id_param;
    
    -- Check if task can be completed based on requirements
    SELECT * INTO receiving_task FROM receiving_tasks WHERE id = receiving_task_id_param;
    
    -- Check ERP reference requirement
    IF receiving_task.requires_erp_reference AND receiving_task.erp_reference_number IS NULL THEN
        can_complete := false;
    END IF;
    
    -- Check original bill upload requirement
    IF receiving_task.requires_original_bill_upload AND NOT receiving_task.original_bill_uploaded THEN
        can_complete := false;
    END IF;
    
    -- If all requirements are met, mark as completed
    IF can_complete AND NOT receiving_task.task_completed THEN
        UPDATE receiving_tasks 
        SET 
            task_completed = true,
            completed_at = now(),
            updated_at = now()
        WHERE id = receiving_task_id_param;
        
        -- Update the main task assignment status
        UPDATE task_assignments 
        SET 
            status = 'completed',
            completed_at = now()
        WHERE id = receiving_task.assignment_id;
        
        -- Update the main task status
        UPDATE tasks 
        SET 
            status = 'completed',
            completion_percentage = 100,
            updated_at = now()
        WHERE id = receiving_task.task_id;
        
        RETURN true;
    END IF;
    
    RETURN false;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- View for receiving tasks with details
-- =============================================

CREATE OR REPLACE VIEW receiving_tasks_detailed AS
SELECT 
    rt.id,
    rt.receiving_record_id,
    rt.task_id,
    rt.assignment_id,
    rt.role_type,
    rt.assigned_user_id,
    rt.requires_erp_reference,
    rt.requires_original_bill_upload,
    rt.requires_reassignment,
    rt.requires_task_finished_mark,
    rt.erp_reference_number,
    rt.original_bill_uploaded,
    rt.original_bill_file_path,
    rt.task_completed,
    rt.completed_at,
    rt.clearance_certificate_url,
    rt.created_at,
    rt.updated_at,
    
    -- Task details
    t.title as task_title,
    t.description as task_description,
    t.status as task_status,
    t.priority as task_priority,
    t.due_datetime as task_due_datetime,
    
    -- Assignment details
    ta.status as assignment_status,
    ta.started_at as assignment_started_at,
    ta.deadline_datetime as assignment_deadline,
    
    -- Receiving record details
    rr.vendor_id,
    rr.branch_id,
    rr.bill_date,
    rr.bill_amount,
    rr.bill_number,
    
    -- Calculated fields
    CASE 
        WHEN ta.deadline_datetime IS NOT NULL AND ta.deadline_datetime < now() AND NOT rt.task_completed THEN true
        ELSE false
    END as is_overdue,
    
    CASE 
        WHEN rt.requires_erp_reference AND rt.erp_reference_number IS NULL THEN false
        WHEN rt.requires_original_bill_upload AND NOT rt.original_bill_uploaded THEN false
        ELSE true
    END as can_be_completed
    
FROM receiving_tasks rt
LEFT JOIN tasks t ON rt.task_id = t.id
LEFT JOIN task_assignments ta ON rt.assignment_id = ta.id
LEFT JOIN receiving_records rr ON rt.receiving_record_id = rr.id
ORDER BY rt.created_at DESC;

-- =============================================
-- Function to get receiving tasks for user
-- =============================================

CREATE OR REPLACE FUNCTION get_receiving_tasks_for_user(
    user_id_param UUID,
    status_filter VARCHAR DEFAULT NULL,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE(
    task_id UUID,
    title VARCHAR,
    description TEXT,
    role_type VARCHAR,
    status VARCHAR,
    priority VARCHAR,
    requires_erp_reference BOOLEAN,
    requires_original_bill_upload BOOLEAN,
    erp_reference_number VARCHAR,
    original_bill_uploaded BOOLEAN,
    clearance_certificate_url TEXT,
    deadline_datetime TIMESTAMPTZ,
    is_overdue BOOLEAN,
    can_be_completed BOOLEAN,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rtd.task_id,
        rtd.task_title,
        rtd.task_description,
        rtd.role_type,
        rtd.assignment_status,
        rtd.task_priority,
        rtd.requires_erp_reference,
        rtd.requires_original_bill_upload,
        rtd.erp_reference_number,
        rtd.original_bill_uploaded,
        rtd.clearance_certificate_url,
        rtd.assignment_deadline,
        rtd.is_overdue,
        rtd.can_be_completed,
        rtd.created_at
    FROM receiving_tasks_detailed rtd
    WHERE rtd.assigned_user_id = user_id_param
      AND (status_filter IS NULL OR rtd.assignment_status = status_filter)
      AND NOT rtd.task_completed
    ORDER BY rtd.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Function to get receiving task statistics
-- =============================================

CREATE OR REPLACE FUNCTION get_receiving_task_statistics(
    branch_id_param INTEGER DEFAULT NULL,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_tasks BIGINT,
    completed_tasks BIGINT,
    pending_tasks BIGINT,
    overdue_tasks BIGINT,
    tasks_by_role JSONB,
    completion_rate DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE task_completed = true) as completed_tasks,
        COUNT(*) FILTER (WHERE task_completed = false) as pending_tasks,
        COUNT(*) FILTER (WHERE is_overdue = true AND task_completed = false) as overdue_tasks,
        jsonb_object_agg(
            role_type, 
            jsonb_build_object(
                'total', role_count,
                'completed', role_completed
            )
        ) as tasks_by_role,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(*) FILTER (WHERE task_completed = true) * 100.0) / COUNT(*), 2)
            ELSE 0
        END as completion_rate
    FROM (
        SELECT 
            rtd.role_type,
            rtd.task_completed,
            rtd.is_overdue,
            COUNT(*) OVER (PARTITION BY rtd.role_type) as role_count,
            COUNT(*) FILTER (WHERE rtd.task_completed = true) OVER (PARTITION BY rtd.role_type) as role_completed
        FROM receiving_tasks_detailed rtd
        WHERE (branch_id_param IS NULL OR rtd.branch_id = branch_id_param)
          AND (date_from IS NULL OR rtd.created_at >= date_from)
          AND (date_to IS NULL OR rtd.created_at <= date_to)
    ) stats
    GROUP BY ();
END;
$$ LANGUAGE plpgsql;

-- Add RLS policies for receiving_tasks table
ALTER TABLE receiving_tasks ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their receiving tasks" ON receiving_tasks;
DROP POLICY IF EXISTS "Users can update their receiving tasks" ON receiving_tasks;

-- Users can view receiving tasks assigned to them or from their branch
CREATE POLICY "Users can view their receiving tasks" ON receiving_tasks
    FOR SELECT USING (
        assigned_user_id = auth.uid() OR
        receiving_record_id IN (
            SELECT id FROM receiving_records 
            WHERE branch_id IN (
                SELECT branch_id FROM users WHERE id = auth.uid()
            )
        )
    );

-- Users can update receiving tasks assigned to them
CREATE POLICY "Users can update their receiving tasks" ON receiving_tasks
    FOR UPDATE USING (assigned_user_id = auth.uid());

-- Receiving tasks system created successfully with role-specific task generation