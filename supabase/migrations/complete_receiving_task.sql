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
  original_bill_file_path_param TEXT DEFAULT NULL,
  has_erp_purchase_invoice BOOLEAN DEFAULT FALSE,
  has_pr_excel_file BOOLEAN DEFAULT FALSE,
  has_original_bill BOOLEAN DEFAULT FALSE
)
RETURNS JSON AS $$
DECLARE
  v_task RECORD;
  v_receiving_record_id UUID;
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
  
  -- For Inventory Manager, check required fields
  IF v_task.role_type = 'inventory_manager' THEN
    IF NOT has_erp_purchase_invoice THEN
      RETURN json_build_object(
        'success', false,
        'error', 'ERP Purchase Invoice Reference is required for Inventory Manager',
        'error_code', 'MISSING_ERP_REFERENCE'
      );
    END IF;
    
    IF NOT has_pr_excel_file THEN
      RETURN json_build_object(
        'success', false,
        'error', 'PR Excel file is required for Inventory Manager',
        'error_code', 'MISSING_PR_EXCEL'
      );
    END IF;
    
    IF NOT has_original_bill THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Original bill is required for Inventory Manager',
        'error_code', 'MISSING_ORIGINAL_BILL'
      );
    END IF;
  END IF;
  
  -- Store receiving record ID for later update
  v_receiving_record_id := v_task.receiving_record_id;
  
  -- Update the receiving task
  UPDATE receiving_tasks
  SET 
    task_status = 'completed',
    task_completed = true,
    completed_at = NOW(),
    completed_by_user_id = user_id_param,
    erp_reference_number = COALESCE(erp_reference_param, erp_reference_number),
    original_bill_file_path = COALESCE(original_bill_file_path_param, original_bill_file_path),
    original_bill_uploaded = CASE 
      WHEN original_bill_file_path_param IS NOT NULL OR has_original_bill THEN true
      ELSE original_bill_uploaded
    END,
    updated_at = NOW()
  WHERE id = receiving_task_id_param;
  
  -- If this is an Inventory Manager task, update the receiving_records table
  IF v_task.role_type = 'inventory_manager' THEN
    UPDATE receiving_records
    SET 
      erp_purchase_invoice_uploaded = has_erp_purchase_invoice,
      pr_excel_file_uploaded = has_pr_excel_file,
      original_bill_uploaded = has_original_bill,
      updated_at = NOW()
    WHERE id = v_receiving_record_id;
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'task_id', receiving_task_id_param,
    'completed_at', NOW(),
    'completed_by', user_id_param,
    'receiving_record_updated', CASE 
      WHEN v_task.role_type = 'inventory_manager' THEN true 
      ELSE false 
    END
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
