-- =====================================================
-- FUNCTION: get_user_receiving_tasks_dashboard
-- =====================================================
-- Purpose: Get receiving tasks dashboard for a specific user
-- Returns: User's tasks with statistics
-- =====================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_user_receiving_tasks_dashboard(UUID);

CREATE OR REPLACE FUNCTION get_user_receiving_tasks_dashboard(
  user_id_param UUID
)
RETURNS JSON AS $$
DECLARE
  v_result JSON;
  v_pending_count INT;
  v_completed_count INT;
  v_overdue_count INT;
BEGIN
  -- Count statistics
  SELECT COUNT(*) INTO v_pending_count
  FROM receiving_tasks
  WHERE assigned_user_id = user_id_param
  AND task_completed = false
  AND task_status != 'completed';
  
  SELECT COUNT(*) INTO v_completed_count
  FROM receiving_tasks
  WHERE assigned_user_id = user_id_param
  AND (task_completed = true OR task_status = 'completed');
  
  SELECT COUNT(*) INTO v_overdue_count
  FROM receiving_tasks
  WHERE assigned_user_id = user_id_param
  AND due_date < NOW()
  AND task_completed = false
  AND task_status != 'completed';
  
  -- Build JSON result
  SELECT json_build_object(
    'user_id', user_id_param,
    'statistics', json_build_object(
      'pending_count', v_pending_count,
      'completed_count', v_completed_count,
      'overdue_count', v_overdue_count,
      'total_count', v_pending_count + v_completed_count
    ),
    'recent_tasks', (
      SELECT COALESCE(json_agg(tasks_json), '[]'::json)
      FROM (
        SELECT json_build_object(
          'id', rt.id,
          'receiving_record_id', rt.receiving_record_id,
          'role_type', rt.role_type,
          'title', rt.title,
          'description', rt.description,
          'priority', rt.priority,
          'task_status', rt.task_status,
          'task_completed', rt.task_completed,
          'due_date', rt.due_date,
          'completed_at', rt.completed_at,
          'clearance_certificate_url', rt.clearance_certificate_url,
          'created_at', rt.created_at,
          'bill_number', rr.bill_number,
          'bill_amount', rr.bill_amount,
          'vendor_name', v.vendor_name,
          'branch_name', b.name_en,
          'is_overdue', (rt.due_date < NOW() AND rt.task_status != 'completed'),
          'days_until_due', EXTRACT(DAY FROM (rt.due_date - NOW()))::INTEGER
        ) as tasks_json
        FROM receiving_tasks rt
        LEFT JOIN receiving_records rr ON rr.id = rt.receiving_record_id
        LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
        LEFT JOIN branches b ON b.id = rr.branch_id
        WHERE rt.assigned_user_id = user_id_param
        ORDER BY rt.created_at DESC
        LIMIT 20
      ) tasks
    )
  ) INTO v_result;
  
  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION get_user_receiving_tasks_dashboard TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_receiving_tasks_dashboard TO service_role;
