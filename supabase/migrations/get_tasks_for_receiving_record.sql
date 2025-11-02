-- =====================================================
-- FUNCTION: get_tasks_for_receiving_record
-- =====================================================
-- Purpose: Get all receiving tasks for a specific receiving record
-- Returns: Array of task records with details
-- =====================================================

DROP FUNCTION IF EXISTS get_tasks_for_receiving_record(UUID);

CREATE OR REPLACE FUNCTION get_tasks_for_receiving_record(
  receiving_record_id_param UUID
)
RETURNS TABLE (
  task_id UUID,
  receiving_record_id UUID,
  role_type TEXT,
  title TEXT,
  description TEXT,
  priority TEXT,
  task_status TEXT,
  task_completed BOOLEAN,
  due_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  completed_by_user_id UUID,
  assigned_user_id UUID,
  requires_erp_reference BOOLEAN,
  requires_original_bill_upload BOOLEAN,
  erp_reference_number TEXT,
  original_bill_uploaded BOOLEAN,
  original_bill_file_path TEXT,
  clearance_certificate_url TEXT,
  is_overdue BOOLEAN,
  days_until_due INTEGER,
  bill_number TEXT,
  vendor_name TEXT,
  branch_name TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    rt.id AS task_id,
    rt.receiving_record_id,
    rt.role_type::TEXT,
    rt.title,
    rt.description,
    rt.priority::TEXT,
    rt.task_status::TEXT,
    rt.task_completed,
    rt.due_date,
    rt.created_at,
    rt.completed_at,
    rt.completed_by_user_id,
    rt.assigned_user_id,
    rt.requires_erp_reference,
    rt.requires_original_bill_upload,
    rt.erp_reference_number::TEXT,
    rt.original_bill_uploaded,
    rt.original_bill_file_path,
    rt.clearance_certificate_url,
    -- Calculate if overdue
    CASE 
      WHEN rt.task_completed = false AND rt.due_date < NOW() THEN true
      ELSE false
    END AS is_overdue,
    -- Calculate days until due
    CASE 
      WHEN rt.task_completed = false THEN 
        EXTRACT(DAY FROM (rt.due_date - NOW()))::INTEGER
      ELSE 
        NULL
    END AS days_until_due,
    rr.bill_number::TEXT,
    v.vendor_name::TEXT,
    b.name_en::TEXT AS branch_name
  FROM receiving_tasks rt
  LEFT JOIN receiving_records rr ON rr.id = rt.receiving_record_id
  LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  WHERE rt.receiving_record_id = receiving_record_id_param
  ORDER BY 
    CASE rt.task_status
      WHEN 'pending' THEN 1
      WHEN 'in_progress' THEN 2
      WHEN 'completed' THEN 3
      ELSE 4
    END,
    rt.due_date ASC;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION get_tasks_for_receiving_record TO authenticated;
GRANT EXECUTE ON FUNCTION get_tasks_for_receiving_record TO service_role;
