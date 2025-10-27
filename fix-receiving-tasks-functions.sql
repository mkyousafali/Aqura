-- Fix receiving tasks functions to work with correct table structure
-- This addresses the 500 errors when checking for tasks

-- Step 1: Drop old functions if they exist
DROP FUNCTION IF EXISTS get_tasks_for_receiving_record(uuid);
DROP FUNCTION IF EXISTS process_clearance_certificate_generation(uuid, text, uuid, text, text);
DROP FUNCTION IF EXISTS get_receiving_tasks_for_user(uuid, text, integer);
DROP FUNCTION IF EXISTS get_receiving_task_statistics(integer, text, text);

-- Step 2: Create get_tasks_for_receiving_record function
CREATE OR REPLACE FUNCTION public.get_tasks_for_receiving_record(receiving_record_id_param uuid)
RETURNS TABLE(
    task_id uuid, 
    task_title text, 
    task_description text, 
    assigned_to_user_id uuid, 
    assigned_to_username text, 
    status text, 
    priority text, 
    due_date timestamp with time zone, 
    created_at timestamp with time zone, 
    completed_at timestamp with time zone, 
    attachment_url text
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as task_id,
        t.title as task_title,
        t.description as task_description,
        ta.assigned_to_user_id,
        u.username as assigned_to_username,
        t.status,
        t.priority,
        t.due_datetime as due_date,
        t.created_at,
        t.completed_at,
        t.attachment_url
    FROM tasks t
    LEFT JOIN task_assignments ta ON ta.task_id = t.id
    LEFT JOIN users u ON u.id = ta.assigned_to_user_id
    WHERE t.description LIKE '%' || receiving_record_id_param::text || '%'
       OR t.metadata->>'receiving_record_id' = receiving_record_id_param::text
    ORDER BY t.created_at DESC;
END;
$$;

-- Step 3: Create process_clearance_certificate_generation function
CREATE OR REPLACE FUNCTION public.process_clearance_certificate_generation(
    receiving_record_id_param uuid,
    clearance_certificate_url_param text,
    generated_by_user_id uuid,
    generated_by_name text DEFAULT NULL,
    generated_by_role text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    v_receiving_record RECORD;
    v_vendor RECORD;
    v_branch RECORD;
    v_task_id uuid;
    v_assignment_id uuid;
    v_tasks_created integer := 0;
    v_notifications_sent integer := 0;
    v_user_ids uuid[];
    v_user_id uuid;
    v_user_info RECORD;
BEGIN
    -- Get receiving record with vendor and branch info
    SELECT 
        rr.*,
        v.vendor_name,
        b.name_en as branch_name
    INTO v_receiving_record
    FROM receiving_records rr
    LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id
    LEFT JOIN branches b ON b.id = rr.branch_id
    WHERE rr.id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Receiving record not found',
            'error_code', 'NOT_FOUND'
        );
    END IF;
    
    -- Update receiving record with certificate URL
    UPDATE receiving_records
    SET 
        certificate_url = clearance_certificate_url_param,
        certificate_generated_at = NOW(),
        updated_at = NOW()
    WHERE id = receiving_record_id_param;
    
    -- Collect all relevant user IDs from the receiving record
    v_user_ids := ARRAY[]::uuid[];
    
    -- Add branch manager
    IF v_receiving_record.branch_manager_user_id IS NOT NULL THEN
        v_user_ids := array_append(v_user_ids, v_receiving_record.branch_manager_user_id);
    END IF;
    
    -- Add accountant
    IF v_receiving_record.accountant_user_id IS NOT NULL THEN
        v_user_ids := array_append(v_user_ids, v_receiving_record.accountant_user_id);
    END IF;
    
    -- Add purchasing manager
    IF v_receiving_record.purchasing_manager_user_id IS NOT NULL THEN
        v_user_ids := array_append(v_user_ids, v_receiving_record.purchasing_manager_user_id);
    END IF;
    
    -- Add inventory manager
    IF v_receiving_record.inventory_manager_user_id IS NOT NULL THEN
        v_user_ids := array_append(v_user_ids, v_receiving_record.inventory_manager_user_id);
    END IF;
    
    -- Add shelf stockers
    IF v_receiving_record.shelf_stocker_user_ids IS NOT NULL THEN
        FOREACH v_user_id IN ARRAY v_receiving_record.shelf_stocker_user_ids
        LOOP
            v_user_ids := array_append(v_user_ids, v_user_id);
        END LOOP;
    END IF;
    
    -- Add night supervisors
    IF v_receiving_record.night_supervisor_user_ids IS NOT NULL THEN
        FOREACH v_user_id IN ARRAY v_receiving_record.night_supervisor_user_ids
        LOOP
            v_user_ids := array_append(v_user_ids, v_user_id);
        END LOOP;
    END IF;
    
    -- Add warehouse handlers
    IF v_receiving_record.warehouse_handler_user_ids IS NOT NULL THEN
        FOREACH v_user_id IN ARRAY v_receiving_record.warehouse_handler_user_ids
        LOOP
            v_user_ids := array_append(v_user_ids, v_user_id);
        END LOOP;
    END IF;
    
    -- Create tasks for each user
    FOREACH v_user_id IN ARRAY v_user_ids
    LOOP
        -- Get user info
        SELECT id, username, role INTO v_user_info
        FROM users
        WHERE id = v_user_id;
        
        IF FOUND THEN
            -- Create task
            INSERT INTO tasks (
                title,
                description,
                status,
                priority,
                created_by_user_id,
                due_datetime,
                attachment_url,
                metadata,
                created_at,
                updated_at
            ) VALUES (
                'Review Clearance Certificate - ' || COALESCE(v_receiving_record.vendor_name, 'Unknown Vendor'),
                'Please review the clearance certificate for receiving record ' || receiving_record_id_param::text || 
                '. Bill Number: ' || COALESCE(v_receiving_record.bill_number, 'N/A') ||
                ', Amount: SAR ' || COALESCE(v_receiving_record.bill_amount::text, '0'),
                'pending',
                'high',
                generated_by_user_id,
                NOW() + INTERVAL '7 days',
                clearance_certificate_url_param,
                jsonb_build_object(
                    'receiving_record_id', receiving_record_id_param,
                    'certificate_url', clearance_certificate_url_param,
                    'vendor_name', COALESCE(v_receiving_record.vendor_name, 'Unknown'),
                    'branch_name', COALESCE(v_receiving_record.branch_name, 'Unknown'),
                    'bill_number', v_receiving_record.bill_number,
                    'bill_amount', v_receiving_record.bill_amount
                ),
                NOW(),
                NOW()
            )
            RETURNING id INTO v_task_id;
            
            -- Create task assignment
            INSERT INTO task_assignments (
                task_id,
                assigned_to_user_id,
                assigned_by_user_id,
                assigned_at,
                status
            ) VALUES (
                v_task_id,
                v_user_id,
                generated_by_user_id,
                NOW(),
                'assigned'
            )
            RETURNING id INTO v_assignment_id;
            
            v_tasks_created := v_tasks_created + 1;
            
            -- TODO: Create notification (if notifications table exists)
            -- v_notifications_sent := v_notifications_sent + 1;
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object(
        'success', true,
        'tasks_created', v_tasks_created,
        'notifications_sent', v_notifications_sent,
        'receiving_record_id', receiving_record_id_param,
        'certificate_url', clearance_certificate_url_param
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM,
        'error_code', SQLSTATE
    );
END;
$$;

-- Step 4: Create helper functions for user tasks
CREATE OR REPLACE FUNCTION public.get_receiving_tasks_for_user(
    user_id_param uuid,
    status_filter text DEFAULT NULL,
    limit_count integer DEFAULT 50
)
RETURNS TABLE(
    task_id uuid,
    task_title text,
    task_description text,
    status text,
    priority text,
    due_date timestamp with time zone,
    created_at timestamp with time zone,
    certificate_url text,
    receiving_record_id uuid,
    vendor_name text,
    branch_name text,
    bill_number text,
    bill_amount numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as task_id,
        t.title as task_title,
        t.description as task_description,
        t.status,
        t.priority,
        t.due_datetime as due_date,
        t.created_at,
        t.attachment_url as certificate_url,
        (t.metadata->>'receiving_record_id')::uuid as receiving_record_id,
        t.metadata->>'vendor_name' as vendor_name,
        t.metadata->>'branch_name' as branch_name,
        t.metadata->>'bill_number' as bill_number,
        (t.metadata->>'bill_amount')::numeric as bill_amount
    FROM tasks t
    INNER JOIN task_assignments ta ON ta.task_id = t.id
    WHERE ta.assigned_to_user_id = user_id_param
      AND t.metadata->>'receiving_record_id' IS NOT NULL
      AND (status_filter IS NULL OR t.status = status_filter)
    ORDER BY t.created_at DESC
    LIMIT limit_count;
END;
$$;

-- Step 5: Verification
DO $$
BEGIN
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ Receiving Tasks Functions Created/Updated';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📋 Function: get_tasks_for_receiving_record(uuid)';
    RAISE NOTICE '   → Returns tasks for a specific receiving record';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Function: process_clearance_certificate_generation(...)';
    RAISE NOTICE '   → Creates tasks for all relevant users';
    RAISE NOTICE '   → Updates receiving record with certificate URL';
    RAISE NOTICE '   → Returns JSON with results';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Function: get_receiving_tasks_for_user(uuid, text, int)';
    RAISE NOTICE '   → Returns tasks assigned to a specific user';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
