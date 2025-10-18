-- IMMEDIATE FIX: Replace the function in the live database
-- Copy this entire script and run it in Supabase SQL Editor

-- Update existing records first
UPDATE receiving_tasks SET requires_erp_reference = false WHERE role_type = 'inventory_manager';
UPDATE task_assignments SET require_erp_reference = false WHERE id IN (SELECT ta.id FROM task_assignments ta JOIN receiving_tasks rt ON ta.id = rt.assignment_id WHERE rt.role_type = 'inventory_manager');
UPDATE tasks SET require_erp_reference = false WHERE id IN (SELECT DISTINCT t.id FROM tasks t JOIN task_assignments ta ON t.id = ta.task_id JOIN receiving_tasks rt ON ta.id = rt.assignment_id WHERE rt.role_type = 'inventory_manager');

-- Replace the function with correct types and NO ERP requirement
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
    deadline_datetime TIMESTAMPTZ;
    task_description TEXT;
    total_tasks INTEGER := 0;
    total_notifications INTEGER := 0;
    created_task_ids UUID[] := '{}';
    created_assignment_ids UUID[] := '{}';
BEGIN
    deadline_datetime := now() + INTERVAL '24 hours';
    
    SELECT * INTO receiving_record FROM receiving_records WHERE id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving record not found: %', receiving_record_id_param;
    END IF;
    
    SELECT * INTO vendor_record FROM vendors WHERE erp_vendor_id = receiving_record.vendor_id;
    
    task_description := format('Vendor: %s, Bill Date: %s, Received by: %s',
        COALESCE(vendor_record.vendor_name, 'Unknown Vendor'),
        receiving_record.bill_date::TEXT,
        COALESCE(created_by_name, 'Unknown User')
    );
    
    -- INVENTORY MANAGER TASK - NO ERP REQUIREMENT
    IF receiving_record.inventory_manager_user_id IS NOT NULL THEN
        SELECT create_task(
            'New Delivery Arrived – Enter into Purchase ERP and Upload Original Bill',
            task_description,
            created_by_user_id,
            created_by_name,
            created_by_role,
            'high',
            'receiving_delivery',
            deadline_datetime::DATE,
            deadline_datetime::TIME,
            true,
            false,
            false, -- require_erp_reference = false (NO ERP REQUIRED!)
            false,
            false,
            NULL::INTERVAL,
            NULL::BIGINT,
            receiving_record.branch_id::BIGINT, -- Fixed type casting
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
            deadline_datetime::DATE, deadline_datetime::TIME,
            'high', 'Clearance certificate attached. Original bill upload required.',
            false, false, -- require_erp_reference = false (NO ERP REQUIRED!)
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
    
    RETURN QUERY SELECT total_tasks, total_notifications, created_task_ids, created_assignment_ids;
END;
$$ LANGUAGE plpgsql;

-- Success message
SELECT 'Function updated successfully! ERP requirement removed for inventory managers.' as result;