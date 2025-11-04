-- =====================================================
-- FIX VENDOR PAYMENT SCHEDULES TABLE NAME
-- =====================================================
-- Fix the incorrect table name in complete_receiving_task function
-- vendor_payment_schedules → vendor_payment_schedule
-- =====================================================

-- Drop existing function variants to avoid conflicts with specific signatures
DROP FUNCTION IF EXISTS complete_receiving_task(UUID, UUID);
DROP FUNCTION IF EXISTS complete_receiving_task(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS complete_receiving_task(UUID, UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS complete_receiving_task(receiving_task_id_param UUID, user_id_param UUID, completion_photo_url_param TEXT, completion_notes_param TEXT);

-- Also try dropping any other variants that might exist
DO $$ 
BEGIN
    -- Try to drop all variants of the function
    BEGIN
        EXECUTE 'DROP FUNCTION complete_receiving_task CASCADE';
    EXCEPTION WHEN OTHERS THEN
        -- Ignore errors if function doesn't exist
        NULL;
    END;
END $$;

CREATE FUNCTION complete_receiving_task(
  receiving_task_id_param UUID,
  user_id_param UUID,
  completion_photo_url_param TEXT DEFAULT NULL,
  completion_notes_param TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_task RECORD;
  v_receiving_record RECORD;
  v_payment_schedule RECORD;
  v_result JSONB;
BEGIN
  -- Get task details
  SELECT * INTO v_task
  FROM receiving_tasks
  WHERE id = receiving_task_id_param
    AND assigned_user_id = user_id_param;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Task not found or not assigned to user',
      'error_code', 'TASK_NOT_FOUND'
    );
  END IF;
  
  -- Check if task is already completed
  IF v_task.task_completed THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Task is already completed',
      'error_code', 'TASK_ALREADY_COMPLETED'
    );
  END IF;
  
  -- Get receiving record
  SELECT * INTO v_receiving_record
  FROM receiving_records
  WHERE id = v_task.receiving_record_id;
  
  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Receiving record not found',
      'error_code', 'RECEIVING_RECORD_NOT_FOUND'
    );
  END IF;

  -- Role-specific validations
  IF v_task.role_type = 'inventory_manager' THEN
    -- Check inventory manager requirements
    IF NOT v_receiving_record.erp_purchase_invoice_uploaded THEN
      RETURN json_build_object(
        'success', false,
        'error', 'ERP purchase invoice not uploaded',
        'error_code', 'ERP_INVOICE_REQUIRED'
      );
    END IF;
    
    IF NOT v_receiving_record.pr_excel_file_uploaded THEN
      RETURN json_build_object(
        'success', false,
        'error', 'PR Excel file not uploaded',
        'error_code', 'PR_EXCEL_REQUIRED'
      );
    END IF;
    
    IF NOT v_receiving_record.original_bill_uploaded THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Original bill not uploaded',
        'error_code', 'ORIGINAL_BILL_REQUIRED'
      );
    END IF;
    
  ELSIF v_task.role_type = 'purchase_manager' THEN
    -- Check purchase manager requirements
    IF NOT v_receiving_record.pr_excel_file_uploaded THEN
      RETURN json_build_object(
        'success', false,
        'error', 'PR Excel file not uploaded by inventory manager',
        'error_code', 'PR_EXCEL_REQUIRED'
      );
    END IF;
    
    -- Check payment schedule verification status
    SELECT * INTO v_payment_schedule
    FROM vendor_payment_schedule  -- Fixed: removed 's' from vendor_payment_schedules
    WHERE receiving_record_id = v_task.receiving_record_id;
    
    IF NOT FOUND THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Payment schedule not found. PR Excel may not be processed yet.',
        'error_code', 'PAYMENT_SCHEDULE_NOT_FOUND'
      );
    END IF;
    
    IF v_payment_schedule.verification_status != 'verified' THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Payment schedule not verified. Current status: ' || COALESCE(v_payment_schedule.verification_status, 'unverified'),
        'error_code', 'PAYMENT_SCHEDULE_NOT_VERIFIED'
      );
    END IF;
    
  ELSIF v_task.role_type = 'accountant' THEN
    -- Check accountant dependency on inventory manager original bill upload
    IF NOT v_receiving_record.original_bill_uploaded OR v_receiving_record.original_bill_url IS NULL THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Original bill not uploaded by the inventory manager – please follow up.',
        'error_code', 'DEPENDENCIES_NOT_MET'
      );
    END IF;
  END IF;

  -- Update the task as completed
  UPDATE receiving_tasks
  SET 
    task_completed = true,
    completed_at = CURRENT_TIMESTAMP,
    completion_photo_url = completion_photo_url_param,
    completion_notes = completion_notes_param
  WHERE id = receiving_task_id_param;
  
  -- Return success
  v_result := json_build_object(
    'success', true,
    'message', 'Task completed successfully',
    'task_id', receiving_task_id_param,
    'role_type', v_task.role_type,
    'completed_at', CURRENT_TIMESTAMP
  );
  
  RETURN v_result;
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM,
    'error_code', 'INTERNAL_ERROR'
  );
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION complete_receiving_task TO authenticated;
GRANT EXECUTE ON FUNCTION complete_receiving_task TO service_role;