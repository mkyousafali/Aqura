-- =====================================================
-- BACKWARD COMPATIBILITY SOLUTION
-- =====================================================
-- Add rule effective date to handle existing vs new tasks
-- =====================================================

-- 1. Add migration timestamp column to track when rules became effective
ALTER TABLE receiving_tasks 
ADD COLUMN rule_effective_date TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- 2. Set current timestamp as effective date for NEW rule enforcement
-- All existing tasks get NULL (meaning they're exempt from new rules)
UPDATE receiving_tasks 
SET rule_effective_date = NOW() 
WHERE task_completed = FALSE AND created_at >= NOW();

-- 3. Update the dependency checking function to respect rule effective date
CREATE OR REPLACE FUNCTION check_receiving_task_dependencies(
  receiving_record_id_param UUID,
  role_type_param VARCHAR(50)
)
RETURNS JSON AS $$
DECLARE
  dependency_roles VARCHAR(50)[];
  missing_deps TEXT[] := ARRAY[]::TEXT[];
  photo_deps JSONB := '{}'::JSONB;
  task_record RECORD;
  dep_role VARCHAR(50);
  dep_task RECORD;
  is_rule_exempt BOOLEAN := FALSE;
BEGIN
  -- Get the current task details
  SELECT * INTO task_record
  FROM receiving_tasks 
  WHERE receiving_record_id = receiving_record_id_param 
    AND role_type = role_type_param
  LIMIT 1;

  -- Check if this task is exempt from new rules (legacy task)
  IF task_record.rule_effective_date IS NULL THEN
    is_rule_exempt := TRUE;
  END IF;

  -- Get dependency roles from template (only if not exempt)
  IF NOT is_rule_exempt THEN
    SELECT depends_on_role_types INTO dependency_roles
    FROM receiving_task_templates 
    WHERE role_type = role_type_param;
  END IF;

  -- If no dependencies or task is exempt, allow completion
  IF dependency_roles IS NULL OR array_length(dependency_roles, 1) IS NULL OR is_rule_exempt THEN
    RETURN json_build_object(
      'can_complete', true,
      'missing_dependencies', ARRAY[]::TEXT[],
      'dependency_photos', '{}'::JSONB,
      'rule_exempt', is_rule_exempt
    );
  END IF;

  -- Check each dependency
  FOREACH dep_role IN ARRAY dependency_roles LOOP
    SELECT * INTO dep_task
    FROM receiving_tasks
    WHERE receiving_record_id = receiving_record_id_param
      AND role_type = dep_role
      AND task_completed = true
    LIMIT 1;

    IF NOT FOUND THEN
      missing_deps := array_append(missing_deps, dep_role);
    ELSE
      -- For shelf_stocker dependency, check photo requirement (only for non-exempt tasks)
      IF dep_role = 'shelf_stocker' AND NOT is_rule_exempt THEN
        -- Check if shelf stocker task is also rule-exempt
        IF dep_task.rule_effective_date IS NULL THEN
          -- Shelf stocker is exempt, photo not required
          photo_deps := photo_deps || jsonb_build_object(dep_role, dep_task.completion_photo_url);
        ELSE
          -- Shelf stocker must have photo
          IF dep_task.completion_photo_url IS NULL THEN
            missing_deps := array_append(missing_deps, dep_role || ' (photo required)');
          ELSE
            photo_deps := photo_deps || jsonb_build_object(dep_role, dep_task.completion_photo_url);
          END IF;
        END IF;
      ELSE
        -- Non-photo dependency or exempt task
        photo_deps := photo_deps || jsonb_build_object(dep_role, dep_task.completion_photo_url);
      END IF;
    END IF;
  END LOOP;

  RETURN json_build_object(
    'can_complete', array_length(missing_deps, 1) IS NULL,
    'missing_dependencies', missing_deps,
    'dependency_photos', photo_deps,
    'rule_exempt', is_rule_exempt
  );
END;
$$ LANGUAGE plpgsql;

-- 4. Update the complete_receiving_task function to handle photo requirements based on rule exemption
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
  is_rule_exempt BOOLEAN := FALSE;
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

  -- Check if task is exempt from new rules
  IF v_task.rule_effective_date IS NULL THEN
    is_rule_exempt := TRUE;
  END IF;

  -- Get template for requirements (only if not exempt)
  IF NOT is_rule_exempt THEN
    SELECT * INTO v_template
    FROM receiving_task_templates
    WHERE role_type = v_task.role_type;

    -- Check photo requirement for non-exempt tasks
    IF v_template.require_photo_upload AND completion_photo_url_param IS NULL THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Photo upload is required for this role',
        'error_code', 'PHOTO_REQUIRED'
      );
    END IF;

    -- Check dependencies for non-exempt tasks
    dependency_check_result := check_receiving_task_dependencies(
      v_task.receiving_record_id, 
      v_task.role_type
    );

    IF NOT (dependency_check_result->>'can_complete')::BOOLEAN THEN
      RETURN json_build_object(
        'success', false,
        'error', 'Cannot complete task. Missing dependencies: ' || 
                array_to_string(
                  ARRAY(SELECT jsonb_array_elements_text(dependency_check_result->'missing_dependencies')), 
                  ', '
                ),
        'error_code', 'DEPENDENCIES_NOT_MET',
        'missing_dependencies', dependency_check_result->'missing_dependencies'
      );
    END IF;
  END IF;

  -- Rest of the function continues as before...
  v_receiving_record_id := v_task.receiving_record_id;

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
    'rule_exempt', is_rule_exempt,
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