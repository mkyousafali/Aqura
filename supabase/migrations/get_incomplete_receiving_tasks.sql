-- =====================================================
-- FUNCTION: get_incomplete_receiving_tasks
-- =====================================================
-- Purpose: Get all incomplete/pending receiving tasks
-- =====================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_incomplete_receiving_tasks();

CREATE OR REPLACE FUNCTION get_incomplete_receiving_tasks()
RETURNS TABLE (
  id UUID,
  receiving_record_id UUID,
  template_id UUID,
  role_type VARCHAR(50),
  title TEXT,
  description TEXT,
  priority VARCHAR(20),
  task_status VARCHAR(50),
  task_completed BOOLEAN,
  due_date TIMESTAMP WITH TIME ZONE,
  assigned_user_id UUID,
  completed_at TIMESTAMP WITH TIME ZONE,
  completed_by_user_id UUID,
  clearance_certificate_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE,
  bill_number VARCHAR(100),
  bill_amount NUMERIC(15, 2),
  vendor_name TEXT,
  branch_name TEXT,
  assigned_user_name TEXT,
  is_overdue BOOLEAN,
  days_until_due INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    rt.id,
    rt.receiving_record_id,
    rt.template_id,
    rt.role_type,
    rt.title,
    rt.description,
    rt.priority,
    rt.task_status,
    rt.task_completed,
    rt.due_date,
    rt.assigned_user_id,
    rt.completed_at,
    rt.completed_by_user_id,
    rt.clearance_certificate_url,
    rt.created_at,
    rr.bill_number,
    rr.bill_amount,
    v.vendor_name,
    b.name_en as branch_name,
    u1.username as assigned_user_name,
    (rt.due_date < NOW() AND rt.task_status != 'completed') as is_overdue,
    EXTRACT(DAY FROM (rt.due_date - NOW()))::INTEGER as days_until_due
  FROM receiving_tasks rt
  LEFT JOIN receiving_records rr ON rr.id = rt.receiving_record_id
  LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  LEFT JOIN users u1 ON u1.id = rt.assigned_user_id
  WHERE rt.task_completed = false AND rt.task_status != 'completed'
  ORDER BY rt.due_date ASC, rt.priority DESC;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION get_incomplete_receiving_tasks TO authenticated;
GRANT EXECUTE ON FUNCTION get_incomplete_receiving_tasks TO service_role;
