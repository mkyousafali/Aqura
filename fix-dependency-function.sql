-- =====================================================
-- FIX DEPENDENCY FUNCTION ISSUES
-- =====================================================
-- Fix the complete_receiving_task function to properly handle
-- JSON vs JSONB and improve dependency error messages
-- =====================================================

CREATE OR REPLACE FUNCTION complete_receiving_task(
  receiving_task_id_param UUID,
  user_id_param UUID,
  erp_reference_param VARCHAR(255) DEFAULT NULL,
  original_bill_file_path_param TEXT DEFAULT NULL,
  has_erp_purchase_invoice BOOLEAN DEFAULT FALSE,
  has_pr_excel_file BOOLEAN DEFAULT FALSE,
  has_original_bill BOOLEAN DEFAULT FALSE,
  completion_photo_url_param TEXT DEFAULT NULL,
  completion_notes_param TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_task RECORD;
  v_receiving_record_id UUID;
  v_template RECORD;
  dependency_check_result JSON;
  accountant_dependency_result JSON;
  blocking_roles_array TEXT[];
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

  v_receiving_record_id := v_task.receiving_record_id;

  -- Get template for requirements
  SELECT * INTO v_template
  FROM receiving_task_templates
  WHERE role_type = v_task.role_type;

  -- SPECIAL CHECK FOR ACCOUNTANT: Must wait for inventory manager to upload original bill
  IF v_task.role_type = 'accountant' THEN
    accountant_dependency_result := check_accountant_dependency(v_receiving_record_id);
    
    IF NOT (accountant_dependency_result->>'can_complete')::BOOLEAN THEN
      RETURN json_build_object(
        'success', false,
        'error', accountant_dependency_result->>'error',
        'error_code', accountant_dependency_result->>'error_code',
        'message', accountant_dependency_result->>'message'
      );
    END IF;
  END IF;

  -- Check photo requirement (for non-exempt tasks)
  IF v_template.require_photo_upload AND completion_photo_url_param IS NULL THEN
    -- Check if task is exempt from new rules (backward compatibility)
    IF v_task.rule_effective_date IS NOT NULL THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Photo upload is required for this role',
        'error_code', 'PHOTO_REQUIRED'
      );
    END IF;
  END IF;

  -- Check other dependencies (existing logic) - FIXED VERSION
  IF v_template.depends_on_role_types IS NOT NULL AND array_length(v_template.depends_on_role_types, 1) > 0 THEN
    dependency_check_result := check_receiving_task_dependencies(
      v_receiving_record_id, 
      v_task.role_type
    );

    IF NOT (dependency_check_result->>'can_complete')::BOOLEAN THEN
      -- Extract blocking roles properly from JSON
      IF dependency_check_result ? 'blocking_roles' THEN
        -- Convert JSON array to PostgreSQL array
        SELECT ARRAY(
          SELECT json_array_elements_text(dependency_check_result->'blocking_roles')
        ) INTO blocking_roles_array;
      ELSE
        blocking_roles_array := ARRAY[]::TEXT[];
      END IF;

      RETURN json_build_object(
        'success', false,
        'error', 'Cannot complete task. Missing dependencies: ' || 
                COALESCE(array_to_string(blocking_roles_array, ', '), 'Unknown dependencies'),
        'error_code', 'DEPENDENCIES_NOT_MET',
        'blocking_roles', blocking_roles_array,
        'dependency_details', dependency_check_result
      );
    END IF;
  END IF;

  -- Validation for Inventory Manager role
  IF v_task.role_type = 'inventory_manager' THEN
    IF erp_reference_param IS NULL OR erp_reference_param = '' THEN
      RETURN json_build_object(
        'success', false,
        'error', 'ERP reference is required for Inventory Manager',
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

  -- For Purchase Manager, check PR Excel upload and verification status
  IF v_task.role_type = 'purchase_manager' THEN
    DECLARE
      v_receiving_record RECORD;
      v_payment_schedule RECORD;
    BEGIN
      -- Get receiving record details
      SELECT * INTO v_receiving_record
      FROM receiving_records
      WHERE id = v_task.receiving_record_id;
      
      -- Check if PR Excel file is uploaded
      IF v_receiving_record.pr_excel_file_url IS NULL OR v_receiving_record.pr_excel_file_url = '' THEN
        RETURN json_build_object(
          'success', false,
          'error', 'PR Excel not uploaded',
          'error_code', 'PR_EXCEL_NOT_UPLOADED'
        );
      END IF;
      
      -- Get payment schedule to check verification status
      SELECT * INTO v_payment_schedule
      FROM vendor_payment_schedules
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
    END;
  END IF;

  -- Update the task
  UPDATE receiving_tasks
  SET 
    task_status = 'completed',
    task_completed = true,
    completed_at = NOW(),
    completed_by_user_id = user_id_param,
    completion_photo_url = COALESCE(completion_photo_url_param, completion_photo_url),
    completion_notes = COALESCE(completion_notes_param, completion_notes),
    erp_reference_number = CASE 
      WHEN v_task.role_type = 'inventory_manager' THEN erp_reference_param 
      ELSE erp_reference_number
    END,
    original_bill_uploaded = CASE 
      WHEN v_task.role_type = 'inventory_manager' THEN has_original_bill
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
    'dependency_check', CASE 
      WHEN v_task.role_type = 'accountant' THEN accountant_dependency_result
      ELSE dependency_check_result
    END,
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

-- Also fix the dependency checking function to provide better role information
CREATE OR REPLACE FUNCTION check_receiving_task_dependencies(
  receiving_record_id_param UUID,
  role_type_param TEXT
)
RETURNS JSON AS $$
DECLARE
  template_record RECORD;
  dependency_role TEXT;
  dependency_task RECORD;
  missing_dependencies TEXT[] := ARRAY[]::TEXT[];
  blocking_roles TEXT[] := ARRAY[]::TEXT[];
  completed_dependencies TEXT[] := ARRAY[]::TEXT[];
BEGIN
  -- Get the template for the role
  SELECT * INTO template_record
  FROM receiving_task_templates
  WHERE role_type = role_type_param;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'can_complete', false,
      'error', 'Template not found for role: ' || role_type_param,
      'missing_dependencies', ARRAY[]::TEXT[],
      'blocking_roles', ARRAY[]::TEXT[],
      'completed_dependencies', ARRAY[]::TEXT[]
    );
  END IF;

  -- If no dependencies, can complete
  IF template_record.depends_on_role_types IS NULL OR array_length(template_record.depends_on_role_types, 1) = 0 THEN
    RETURN json_build_object(
      'can_complete', true,
      'missing_dependencies', ARRAY[]::TEXT[],
      'blocking_roles', ARRAY[]::TEXT[],
      'completed_dependencies', ARRAY[]::TEXT[]
    );
  END IF;

  -- Check each dependency
  FOREACH dependency_role IN ARRAY template_record.depends_on_role_types
  LOOP
    SELECT * INTO dependency_task
    FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
      AND role_type = dependency_role
      AND task_completed = true
    LIMIT 1;

    IF NOT FOUND THEN
      missing_dependencies := array_append(missing_dependencies, dependency_role);
      
      -- Create user-friendly role names for blocking message
      CASE dependency_role
        WHEN 'inventory_manager' THEN
          blocking_roles := array_append(blocking_roles, 'Inventory Manager must complete their task first');
        WHEN 'purchase_manager' THEN
          blocking_roles := array_append(blocking_roles, 'Purchase Manager must complete their task first');
        WHEN 'shelf_stocker' THEN
          blocking_roles := array_append(blocking_roles, 'Shelf Stocker must complete their task first');
        WHEN 'warehouse_handler' THEN
          blocking_roles := array_append(blocking_roles, 'Warehouse Handler must complete their task first');
        ELSE
          blocking_roles := array_append(blocking_roles, dependency_role || ' must complete their task first');
      END CASE;
    ELSE
      completed_dependencies := array_append(completed_dependencies, dependency_role);
    END IF;
  END LOOP;

  -- Return result
  IF array_length(missing_dependencies, 1) > 0 THEN
    RETURN json_build_object(
      'can_complete', false,
      'missing_dependencies', missing_dependencies,
      'blocking_roles', blocking_roles,
      'completed_dependencies', completed_dependencies
    );
  ELSE
    RETURN json_build_object(
      'can_complete', true,
      'missing_dependencies', ARRAY[]::TEXT[],
      'blocking_roles', ARRAY[]::TEXT[],
      'completed_dependencies', completed_dependencies
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions
GRANT EXECUTE ON FUNCTION check_receiving_task_dependencies TO authenticated;
GRANT EXECUTE ON FUNCTION check_receiving_task_dependencies TO service_role;