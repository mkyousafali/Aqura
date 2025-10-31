-- ============================================================================
-- Manual Reminder Function - Can resend reminders
-- ============================================================================
-- This function allows manual resending of reminders even if already sent

DROP FUNCTION IF EXISTS get_overdue_tasks_for_manual_reminder();

CREATE OR REPLACE FUNCTION get_overdue_tasks_for_manual_reminder()
RETURNS TABLE (
  assignment_id UUID,
  task_id UUID,
  task_title TEXT,
  assigned_to_user_id UUID,
  user_name VARCHAR(255),
  deadline TIMESTAMPTZ,
  hours_overdue NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ta.id as assignment_id,
    t.id as task_id,
    t.title as task_title,
    ta.assigned_to_user_id,
    u.username as user_name,
    COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) as deadline,
    EXTRACT(EPOCH FROM (NOW() - COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime))) / 3600 as hours_overdue
  FROM task_assignments ta
  JOIN tasks t ON t.id = ta.task_id
  JOIN users u ON u.id = ta.assigned_to_user_id
  LEFT JOIN task_completions tc ON tc.assignment_id = ta.id
  WHERE tc.id IS NULL  -- Not completed
    AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) IS NOT NULL  -- Has deadline
    AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) < NOW()  -- Overdue
    -- NOTE: No check for existing reminders - allows resending
  ORDER BY hours_overdue DESC;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_overdue_tasks_for_manual_reminder() TO service_role;
GRANT EXECUTE ON FUNCTION get_overdue_tasks_for_manual_reminder() TO authenticated;

COMMENT ON FUNCTION get_overdue_tasks_for_manual_reminder() IS 'Returns ALL overdue tasks for manual reminder - allows resending';
