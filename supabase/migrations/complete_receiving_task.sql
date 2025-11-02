-- =====================================================
-- FUNCTION: complete_receiving_task
-- =====================================================
-- Purpose: Mark a receiving task as completed
-- Updates: task_status, task_completed, completed_at, completed_by_user_id
-- =====================================================

-- Drop all existing versions of the function
DROP FUNCTION IF EXISTS complete_receiving_task(UUID, UUID, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS complete_receiving_task(UUID, UUID);
DROP FUNCTION IF EXISTS complete_receiving_task;

CREATE OR REPLACE FUNCTION complete_receiving_task(
  receiving_task_id_param UUID,
  user_id_param UUID,
  erp_reference_param VARCHAR(255) DEFAULT NULL,
  original_bill_file_path_param TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_task RECORD;
BEGIN
  -- Get the task
  SELECT * INTO v_task
  FROM receiving_tasks
  WHERE id = receiving_task_id_param;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Task not found',
      'error_code', 'TASK_NOT_FOUND'
    );
  END IF;
  
  -- Check if already completed
  IF v_task.task_completed = true THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Task already completed',
      'error_code', 'TASK_ALREADY_COMPLETED'
    );
  END IF;
  
  -- Update the task
  UPDATE receiving_tasks
  SET 
    task_status = 'completed',
    task_completed = true,
    completed_at = NOW(),
    completed_by_user_id = user_id_param,
    erp_reference_number = COALESCE(erp_reference_param, erp_reference_number),
    original_bill_file_path = COALESCE(original_bill_file_path_param, original_bill_file_path),
    original_bill_uploaded = CASE 
      WHEN original_bill_file_path_param IS NOT NULL THEN true
      ELSE original_bill_uploaded
    END,
    updated_at = NOW()
  WHERE id = receiving_task_id_param;
  
  RETURN json_build_object(
    'success', true,
    'task_id', receiving_task_id_param,
    'completed_at', NOW(),
    'completed_by', user_id_param
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'error_code', 'INTERNAL_ERROR'
  );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION complete_receiving_task TO authenticated;
GRANT EXECUTE ON FUNCTION complete_receiving_task TO service_role;
