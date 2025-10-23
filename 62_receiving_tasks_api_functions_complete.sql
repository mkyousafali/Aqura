-- Migration: Create receiving tasks API functions
-- File: 62_receiving_tasks_api_functions_complete.sql
-- Description: Creates the missing database functions for receiving tasks API

BEGIN;

-- Drop existing function if it exists (to handle return type changes)
DROP FUNCTION IF EXISTS get_tasks_for_receiving_record(uuid);

-- Create function to get tasks for receiving record
CREATE OR REPLACE FUNCTION get_tasks_for_receiving_record(p_receiving_record_id uuid)
RETURNS TABLE (
  id uuid,
  title text,
  description text,
  status text,
  assigned_to uuid,
  created_at timestamptz,
  due_date timestamptz,
  priority text,
  assignee_name text
) 
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.id,
    t.title,
    t.description,
    t.status,
    ta.assigned_to,
    t.created_at,
    t.due_date,
    t.priority,
    COALESCE(u.username, u.email) as assignee_name
  FROM tasks t
  LEFT JOIN task_assignments ta ON t.id = ta.task_id
  LEFT JOIN users u ON ta.assigned_to = u.id
  WHERE t.receiving_record_id = p_receiving_record_id
  ORDER BY t.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to create receiving tasks
CREATE OR REPLACE FUNCTION create_receiving_tasks(
  p_receiving_record_id uuid,
  p_clearance_certificate_url text,
  p_generated_by_user_id uuid,
  p_generated_by_name text,
  p_generated_by_role text
)
RETURNS json
SECURITY DEFINER
AS $$
DECLARE
  v_result json;
  v_task_count integer := 0;
  v_notification_count integer := 0;
  v_task_id uuid;
  v_user_record record;
  v_receiving_record record;
BEGIN
  -- Get the receiving record details
  SELECT * INTO v_receiving_record 
  FROM receiving_records 
  WHERE id = p_receiving_record_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Receiving record not found';
  END IF;

  -- Create tasks for different roles
  FOR v_user_record IN 
    SELECT DISTINCT u.id, u.username, u.email, ur.role_type
    FROM users u
    JOIN user_roles ur ON u.id = ur.user_id
    WHERE ur.role_type IN ('admin', 'accountant', 'warehouse_manager', 'quality_controller')
    AND u.id != p_generated_by_user_id
  LOOP
    -- Determine task based on role
    CASE v_user_record.role_type
      WHEN 'accountant' THEN
        INSERT INTO tasks (
          title,
          description,
          receiving_record_id,
          priority,
          status,
          created_by,
          created_at
        ) VALUES (
          'Process Payment Entry',
          'Enter payment details into ERP system and upload receipt for receiving record: ' || v_receiving_record.bill_number,
          p_receiving_record_id,
          'high',
          'pending',
          p_generated_by_user_id,
          NOW()
        ) RETURNING id INTO v_task_id;
        
      WHEN 'warehouse_manager' THEN
        INSERT INTO tasks (
          title,
          description,
          receiving_record_id,
          priority,
          status,
          created_by,
          created_at
        ) VALUES (
          'Verify Warehouse Stock',
          'Verify received items are properly stored and documented for: ' || v_receiving_record.bill_number,
          p_receiving_record_id,
          'medium',
          'pending',
          p_generated_by_user_id,
          NOW()
        ) RETURNING id INTO v_task_id;
        
      WHEN 'quality_controller' THEN
        INSERT INTO tasks (
          title,
          description,
          receiving_record_id,
          priority,
          status,
          created_by,
          created_at
        ) VALUES (
          'Quality Inspection',
          'Perform quality inspection of received goods for: ' || v_receiving_record.bill_number,
          p_receiving_record_id,
          'high',
          'pending',
          p_generated_by_user_id,
          NOW()
        ) RETURNING id INTO v_task_id;
        
      ELSE
        INSERT INTO tasks (
          title,
          description,
          receiving_record_id,
          priority,
          status,
          created_by,
          created_at
        ) VALUES (
          'Review Clearance Certificate',
          'Review and approve clearance certificate for: ' || v_receiving_record.bill_number,
          p_receiving_record_id,
          'medium',
          'pending',
          p_generated_by_user_id,
          NOW()
        ) RETURNING id INTO v_task_id;
    END CASE;

    -- Assign task to user
    INSERT INTO task_assignments (task_id, assigned_to, assigned_by, assigned_at)
    VALUES (v_task_id, v_user_record.id, p_generated_by_user_id, NOW());
    
    v_task_count := v_task_count + 1;

    -- Create notification
    INSERT INTO notifications (
      title,
      message,
      type,
      created_by,
      created_at
    ) VALUES (
      'New Task Assigned',
      'You have been assigned a new task related to receiving record: ' || v_receiving_record.bill_number,
      'task_assignment',
      p_generated_by_user_id,
      NOW()
    );

    -- Add notification recipient
    INSERT INTO notification_recipients (
      notification_id,
      user_id,
      is_read,
      created_at
    ) VALUES (
      (SELECT id FROM notifications ORDER BY created_at DESC LIMIT 1),
      v_user_record.id,
      false,
      NOW()
    );
    
    v_notification_count := v_notification_count + 1;
  END LOOP;

  -- Update receiving record with certificate URL
  UPDATE receiving_records 
  SET certificate_url = p_clearance_certificate_url
  WHERE id = p_receiving_record_id;

  -- Return summary
  SELECT json_build_object(
    'tasks_created', v_task_count,
    'notifications_sent', v_notification_count,
    'certificate_url', p_clearance_certificate_url,
    'generated_by', p_generated_by_name,
    'generated_at', NOW()
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMIT;