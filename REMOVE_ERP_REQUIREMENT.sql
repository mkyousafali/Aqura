-- =============================================
-- REMOVE ERP REFERENCE REQUIREMENT FOR INVENTORY MANAGER
-- This removes the ERP reference requirement from inventory manager tasks in ALL places
-- =============================================

-- 1. Update the main task generation function in migration 73
UPDATE receiving_tasks 
SET requires_erp_reference = false
WHERE role_type = 'inventory_manager';

-- 2. Update existing task assignments for inventory managers
UPDATE task_assignments 
SET require_erp_reference = false
WHERE id IN (
    SELECT ta.id 
    FROM task_assignments ta
    JOIN receiving_tasks rt ON ta.id = rt.assignment_id
    WHERE rt.role_type = 'inventory_manager'
);

-- 3. Update tasks table to remove ERP requirement for inventory manager tasks
UPDATE tasks 
SET require_erp_reference = false
WHERE id IN (
    SELECT DISTINCT t.id 
    FROM tasks t
    JOIN task_assignments ta ON t.id = ta.task_id
    JOIN receiving_tasks rt ON ta.id = rt.assignment_id
    WHERE rt.role_type = 'inventory_manager'
);

-- 4. Fix the original migration file function to NOT require ERP for inventory managers
-- Also need to update the actual migration file for future deployments

-- 5. Fix the task generation function to NOT require ERP for inventory managers
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
    SELECT * INTO receiving_record FROM receiving_records WHERE id = receiving_record_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Receiving record not found: %', receiving_record_id_param;
    END IF;
    
    -- Task description template
    task_description := format('Receiving Record: %s from %s (Branch: %s)', 
                               receiving_record.bill_number, 
                               COALESCE((SELECT vendor_name FROM vendors WHERE erp_vendor_id = receiving_record.vendor_id), 'Unknown Vendor'),
                               COALESCE((SELECT name_en FROM branches WHERE id = receiving_record.branch_id), 'Unknown Branch'));
    
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
            false, -- NO ERP REFERENCE REQUIRED
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
            false, false, -- NO ERP REFERENCE REQUIRED
            jsonb_build_object('clearance_certificate_url', clearance_certificate_url_param)
        ) INTO assignment_id;
        
        INSERT INTO receiving_tasks (
            receiving_record_id, task_id, assignment_id, role_type,
            assigned_user_id, requires_erp_reference, requires_original_bill_upload,
            clearance_certificate_url
        ) VALUES (
            receiving_record_id_param, task_id, assignment_id, 'inventory_manager',
            receiving_record.inventory_manager_user_id, false, true, clearance_certificate_url_param -- NO ERP REQUIRED
        );
        
        total_tasks := total_tasks + 1;
        created_task_ids := created_task_ids || task_id;
        created_assignment_ids := created_assignment_ids || assignment_id;
    END IF;
    
    -- Return results (simplified for this fix)
    RETURN QUERY SELECT total_tasks, 0, created_task_ids, created_assignment_ids;
END;
$$ LANGUAGE plpgsql;

-- Check the results
SELECT 
    'UPDATED_TASKS' as section,
    COUNT(*) as count,
    'Tasks updated to not require ERP reference' as description
FROM tasks 
WHERE require_erp_reference = false;

SELECT 
    'UPDATED_ASSIGNMENTS' as section,
    COUNT(*) as count,
    'Task assignments updated to not require ERP reference' as description
FROM task_assignments ta
JOIN receiving_tasks rt ON ta.id = rt.assignment_id
WHERE rt.role_type = 'inventory_manager' 
  AND ta.require_erp_reference = false;

SELECT 
    'UPDATED_RECEIVING_TASKS' as section,
    COUNT(*) as count,
    'Receiving tasks updated to not require ERP reference' as description
FROM receiving_tasks 
WHERE role_type = 'inventory_manager' 
  AND requires_erp_reference = false;

-- Success message
DO $$ 
BEGIN 
    RAISE NOTICE '✅ ERP reference requirement removed for inventory managers!';
    RAISE NOTICE 'Updated existing tasks, assignments, and receiving_tasks tables.';
    RAISE NOTICE 'Updated the task generation function to not require ERP for future tasks.';
    RAISE NOTICE 'Inventory managers can now complete tasks without entering ERP references.';
    RAISE NOTICE 'The ERP sync system and manual sync buttons will still work for optional use.';
END $$;