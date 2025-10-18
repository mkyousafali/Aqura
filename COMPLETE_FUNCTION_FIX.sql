-- Complete function that creates tasks for ALL roles, not just inventory manager
-- This replaces the simplified version with the full implementation

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
            receiving_record.branch_id::BIGINT,
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
        
        SELECT assign_task(
            task_id,
            'primary',
            receiving_record.branch_manager_user_id::TEXT,
            NULL,
            created_by_user_id,
            created_by_name,
            NULL,
            NULL,
            (deadline_datetime)::DATE,
            (deadline_datetime)::TIME,
            'high',
            'Clearance certificate attached',
            false,
            false,
            jsonb_build_object('clearance_certificate_url', clearance_certificate_url_param)
        ) INTO assignment_id;
        
        INSERT INTO receiving_tasks (
            receiving_record_id, task_id, assignment_id, role_type,
            assigned_user_id, requires_reassignment, clearance_certificate_url
        ) VALUES (
            receiving_record_id_param, task_id, assignment_id, 'branch_manager',
            receiving_record.branch_manager_user_id, true, clearance_certificate_url_param
        );
        
        total_tasks := total_tasks + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
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
            receiving_record.branch_id::BIGINT,
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
    END IF;
    
    -- =============================================
    -- 3. Inventory Manager Task - NO ERP REQUIREMENT
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
            false, -- require_erp_reference = false (NO ERP REQUIRED)
            false,
            false,
            NULL::INTERVAL,
            NULL::BIGINT,
            receiving_record.branch_id::BIGINT,
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
            'high', 'Clearance certificate attached. Original bill upload required.',
            false, false, -- require_erp_reference = false (NO ERP REQUIRED)
            jsonb_build_object('clearance_certificate_url', clearance_certificate_url_param)
        ) INTO assignment_id;
        
        INSERT INTO receiving_tasks (
            receiving_record_id, task_id, assignment_id, role_type,
            assigned_user_id, requires_erp_reference, requires_original_bill_upload,
            clearance_certificate_url
        ) VALUES (
            receiving_record_id_param, task_id, assignment_id, 'inventory_manager',
            receiving_record.inventory_manager_user_id, false, true, clearance_certificate_url_param
        );
        
        total_tasks := total_tasks + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
    END IF;
    
    -- Return results
    RETURN QUERY SELECT 
        total_tasks,
        total_notifications,
        created_task_ids,
        created_assignment_ids;
END;
$$ LANGUAGE plpgsql;

-- Also ensure the helper function exists
CREATE OR REPLACE FUNCTION get_tasks_for_receiving_record(
    receiving_record_id_param UUID
)
RETURNS TABLE(
    task_id UUID,
    assignment_id UUID,
    role_type VARCHAR,
    assigned_user_id UUID,
    task_title VARCHAR,
    task_description TEXT,
    task_status VARCHAR,
    assignment_status VARCHAR,
    priority VARCHAR,
    deadline_datetime TIMESTAMPTZ,
    requires_erp_reference BOOLEAN,
    requires_original_bill_upload BOOLEAN,
    requires_reassignment BOOLEAN,
    erp_reference_number VARCHAR,
    original_bill_uploaded BOOLEAN,
    task_completed BOOLEAN,
    is_overdue BOOLEAN,
    can_be_completed BOOLEAN,
    clearance_certificate_url TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rtd.task_id,
        rtd.assignment_id,
        rtd.role_type,
        rtd.assigned_user_id,
        rtd.task_title,
        rtd.task_description,
        rtd.task_status,
        rtd.assignment_status,
        rtd.task_priority,
        rtd.assignment_deadline,
        rtd.requires_erp_reference,
        rtd.requires_original_bill_upload,
        rtd.requires_reassignment,
        rtd.erp_reference_number,
        rtd.original_bill_uploaded,
        rtd.task_completed,
        rtd.is_overdue,
        rtd.can_be_completed,
        rtd.clearance_certificate_url,
        rtd.created_at
    FROM receiving_tasks_detailed rtd
    WHERE rtd.receiving_record_id = receiving_record_id_param
    ORDER BY 
        CASE rtd.role_type
            WHEN 'branch_manager' THEN 1
            WHEN 'inventory_manager' THEN 2
            WHEN 'purchase_manager' THEN 3
            WHEN 'night_supervisor' THEN 4
            WHEN 'warehouse_handler' THEN 5
            WHEN 'shelf_stocker' THEN 6
            WHEN 'accountant' THEN 7
        END,
        rtd.created_at;
END;
$$ LANGUAGE plpgsql;