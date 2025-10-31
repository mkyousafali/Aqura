-- Test the reminder function with full debug output
DO $$
DECLARE
  result_record RECORD;
  found_count INTEGER := 0;
BEGIN
  RAISE NOTICE '=== Testing Reminder Function ===';
  
  -- Call the function and loop through results
  FOR result_record IN 
    SELECT * FROM check_overdue_tasks_and_send_reminders()
  LOOP
    found_count := found_count + 1;
    RAISE NOTICE 'Result %: Task "%" for user "%" (% hours overdue)', 
      found_count, 
      result_record.task_title, 
      result_record.user_name, 
      result_record.hours_overdue;
  END LOOP;
  
  IF found_count = 0 THEN
    RAISE NOTICE 'WARNING: Function returned zero results!';
    RAISE NOTICE 'Checking if query works outside function...';
    
    -- Test the query directly
    FOR result_record IN
      SELECT 
        ta.id,
        t.title,
        u.username
      FROM public.task_assignments ta
      JOIN public.tasks t ON t.id = ta.task_id
      JOIN public.users u ON u.id = ta.assigned_to_user_id
      LEFT JOIN public.task_completions tc ON tc.assignment_id = ta.id
      WHERE tc.id IS NULL
        AND COALESCE(ta.deadline_datetime, ta.deadline_date, t.due_datetime) < NOW()
      LIMIT 5
    LOOP
      RAISE NOTICE 'Direct query found: Task "%" assigned to "%"', result_record.title, result_record.username;
    END LOOP;
  ELSE
    RAISE NOTICE 'SUCCESS: Function returned % results', found_count;
  END IF;
END $$;
