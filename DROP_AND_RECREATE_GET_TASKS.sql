-- DROP AND RECREATE: Fix the get_tasks_for_receiving_record function
-- We need to drop the existing function first, then recreate it with correct types

-- Drop the existing function
DROP FUNCTION IF EXISTS get_tasks_for_receiving_record(UUID);

-- Recreate the function with correct return types
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
    task_status TEXT,
    assignment_status TEXT,
    task_priority TEXT,
    assignment_deadline TIMESTAMPTZ,
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
        rtd.role_type::VARCHAR,
        rtd.assigned_user_id,
        rtd.task_title::VARCHAR,
        rtd.task_description,
        rtd.task_status,
        rtd.assignment_status,
        rtd.task_priority,
        rtd.assignment_deadline,
        rtd.requires_erp_reference,
        rtd.requires_original_bill_upload,
        rtd.requires_reassignment,
        rtd.erp_reference_number::VARCHAR,
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