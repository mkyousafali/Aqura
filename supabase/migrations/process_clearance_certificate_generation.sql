-- =====================================================
-- FUNCTION: process_clearance_certificate_generation
-- =====================================================
-- Purpose: Creates receiving tasks from templates when a clearance certificate is generated
-- Called by: POST /api/receiving-tasks endpoint
-- Architecture: Full separation - only uses receiving_tasks table (not tasks/task_assignments)
-- 
-- Parameters:
--   - receiving_record_id_param: UUID of the receiving record
--   - clearance_certificate_url_param: URL of the generated certificate PDF
--   - generated_by_user_id: UUID of user who generated certificate
--   - generated_by_name: Optional name of user
--   - generated_by_role: Optional role of user
--
-- Returns: JSON with success, tasks_created, notifications_sent
-- =====================================================

CREATE OR REPLACE FUNCTION process_clearance_certificate_generation(
  receiving_record_id_param UUID,
  clearance_certificate_url_param TEXT,
  generated_by_user_id UUID,
  generated_by_name TEXT DEFAULT NULL,
  generated_by_role TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
  v_tasks_created INT := 0;
  v_notifications_sent INT := 0;
  v_receiving_record RECORD;
  v_template RECORD;
  v_task_id UUID;
  v_title TEXT;
  v_description TEXT;
  v_due_date TIMESTAMP;
  v_assigned_user_id UUID;
  v_notification_id UUID;
BEGIN
  
  -- =======================================================
  -- STEP 1: PREVENT DUPLICATE TASK CREATION
  -- =======================================================
  IF EXISTS (
    SELECT 1 FROM receiving_tasks 
    WHERE receiving_record_id = receiving_record_id_param
  ) THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Tasks already exist for this receiving record',
      'error_code', 'DUPLICATE_TASKS',
      'tasks_created', 0,
      'notifications_sent', 0
    );
  END IF;

  -- =======================================================
  -- STEP 2: LOAD RECEIVING RECORD WITH RELATED DATA
  -- =======================================================
  SELECT 
    rr.*,
    v.vendor_name,
    b.name_en as branch_name,
    COALESCE(emp.name, u.username) as received_by_name
  INTO v_receiving_record
  FROM receiving_records rr
  LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  LEFT JOIN users u ON u.id = rr.user_id
  LEFT JOIN hr_employees emp ON emp.id = u.employee_id
  WHERE rr.id = receiving_record_id_param;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Receiving record not found',
      'error_code', 'RECORD_NOT_FOUND',
      'tasks_created', 0,
      'notifications_sent', 0
    );
  END IF;

  -- =======================================================
  -- STEP 3: CREATE TASKS FROM TEMPLATES
  -- =======================================================
  FOR v_template IN 
    SELECT * FROM receiving_task_templates 
    ORDER BY priority DESC, id ASC
  LOOP
    
    -- Replace placeholders in title
    v_title := v_template.title_template;
    v_title := REPLACE(v_title, '{bill_number}', COALESCE(v_receiving_record.bill_number, 'N/A'));
    v_title := REPLACE(v_title, '{vendor_name}', COALESCE(v_receiving_record.vendor_name, 'Unknown Vendor'));
    v_title := REPLACE(v_title, '{branch_name}', COALESCE(v_receiving_record.branch_name, 'Unknown Branch'));
    
    -- Replace placeholders in description
    v_description := v_template.description_template;
    v_description := REPLACE(v_description, '{bill_number}', COALESCE(v_receiving_record.bill_number, 'N/A'));
    v_description := REPLACE(v_description, '{vendor_name}', COALESCE(v_receiving_record.vendor_name, 'Unknown Vendor'));
    v_description := REPLACE(v_description, '{branch_name}', COALESCE(v_receiving_record.branch_name, 'Unknown Branch'));
    v_description := REPLACE(v_description, '{vendor_id}', COALESCE(v_receiving_record.vendor_id::TEXT, 'N/A'));
    v_description := REPLACE(v_description, '{bill_amount}', COALESCE(v_receiving_record.bill_amount::TEXT, 'N/A'));
    v_description := REPLACE(v_description, '{bill_date}', COALESCE(TO_CHAR(v_receiving_record.bill_date, 'YYYY-MM-DD'), 'N/A'));
    v_description := REPLACE(v_description, '{received_by}', COALESCE(v_receiving_record.received_by_name, 'Unknown'));
    v_description := REPLACE(v_description, '{certificate_url}', COALESCE(clearance_certificate_url_param, 'Not Available'));
    
    -- Calculate due date based on template deadline_hours
    -- Using UTC+3 timezone (Middle East Time) for deadline calculation
    v_due_date := (NOW() AT TIME ZONE 'UTC' AT TIME ZONE '+03:00') + (v_template.deadline_hours || ' hours')::INTERVAL;
    
    -- Replace {deadline} placeholder with formatted due date
    v_description := REPLACE(v_description, '{deadline}', TO_CHAR(v_due_date, 'YYYY-MM-DD HH24:MI') || ' UTC+3');
    
    -- Assign user based on role_type from receiving_record user assignments
    v_assigned_user_id := NULL;
    
    CASE v_template.role_type
      WHEN 'branch_manager' THEN
        v_assigned_user_id := v_receiving_record.branch_manager_user_id;
      WHEN 'purchase_manager' THEN
        v_assigned_user_id := v_receiving_record.purchasing_manager_user_id;
      WHEN 'inventory_manager' THEN
        v_assigned_user_id := v_receiving_record.inventory_manager_user_id;
      WHEN 'accountant' THEN
        v_assigned_user_id := v_receiving_record.accountant_user_id;
      WHEN 'night_supervisor' THEN
        -- Take first user from array
        IF v_receiving_record.night_supervisor_user_ids IS NOT NULL AND array_length(v_receiving_record.night_supervisor_user_ids, 1) > 0 THEN
          v_assigned_user_id := v_receiving_record.night_supervisor_user_ids[1];
        END IF;
      WHEN 'warehouse_handler' THEN
        -- Take first user from array
        IF v_receiving_record.warehouse_handler_user_ids IS NOT NULL AND array_length(v_receiving_record.warehouse_handler_user_ids, 1) > 0 THEN
          v_assigned_user_id := v_receiving_record.warehouse_handler_user_ids[1];
        END IF;
      WHEN 'shelf_stocker' THEN
        -- Take first user from array
        IF v_receiving_record.shelf_stocker_user_ids IS NOT NULL AND array_length(v_receiving_record.shelf_stocker_user_ids, 1) > 0 THEN
          v_assigned_user_id := v_receiving_record.shelf_stocker_user_ids[1];
        END IF;
      ELSE
        v_assigned_user_id := NULL;
    END CASE;
    
    -- Generate new UUID for this task
    v_task_id := gen_random_uuid();
    
    -- =======================================================
    -- STEP 4: INSERT INTO receiving_tasks TABLE ONLY
    -- =======================================================
    -- NOTE: We do NOT insert into tasks or task_assignments tables
    -- This is full separation - receiving_tasks is standalone
    INSERT INTO receiving_tasks (
      id,
      receiving_record_id,
      template_id,
      role_type,
      assigned_user_id,
      title,
      description,
      priority,
      due_date,
      task_status,
      task_completed,
      clearance_certificate_url,
      created_at,
      updated_at
    ) VALUES (
      v_task_id,
      receiving_record_id_param,
      v_template.id,
      v_template.role_type,
      v_assigned_user_id,  -- May be NULL if no user with role found
      v_title,
      v_description,
      v_template.priority,
      v_due_date,
      'pending',
      false,
      clearance_certificate_url_param,
      CURRENT_TIMESTAMP,
      CURRENT_TIMESTAMP
    );
    
    v_tasks_created := v_tasks_created + 1;
    
    -- =======================================================
    -- STEP 5: SEND NOTIFICATION (if user is assigned)
    -- =======================================================
    IF v_assigned_user_id IS NOT NULL THEN
      v_notification_id := gen_random_uuid();
      
      -- Create notification record with full details in message
      INSERT INTO notifications (
        id,
        title,
        message,
        type,
        priority,
        created_by,
        created_by_name,
        target_users,
        target_type,
        status,
        created_at,
        sent_at,
        metadata
      ) VALUES (
        v_notification_id,
        'New Receiving Task Assigned',
        '⚠️ New Task Assigned: A new task has been assigned to you: ' || v_title || 
        ' Branch: ' || COALESCE(v_receiving_record.branch_name, 'Unknown') || 
        ' Vendor: ' || COALESCE(v_receiving_record.vendor_name, 'Unknown') || 
        ' (ID: ' || COALESCE(v_receiving_record.vendor_id::TEXT, 'N/A') || ')' ||
        ' Bill Amount: ' || COALESCE(v_receiving_record.bill_amount::TEXT, 'N/A') || 
        ' Bill Number: ' || COALESCE(v_receiving_record.bill_number, 'N/A') || 
        ' Received Date: ' || COALESCE(TO_CHAR(v_receiving_record.bill_date, 'YYYY-MM-DD'), 'N/A') || 
        ' Received By: ' || COALESCE(v_receiving_record.received_by_name, 'Unknown') || 
        ' Deadline: ' || TO_CHAR(v_due_date, 'YYYY-MM-DD HH24:MI') || ' (24 hours)' ||
        ' Please start the delivery placement process and manage the team accordingly.',
        'task',
        v_template.priority,
        generated_by_user_id,
        COALESCE(generated_by_name, 'System'),
        jsonb_build_array(v_assigned_user_id::text),
        'specific_users',
        'published',
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP,
        jsonb_build_object(
          'task_id', v_task_id,
          'receiving_record_id', receiving_record_id_param,
          'role_type', v_template.role_type,
          'bill_number', v_receiving_record.bill_number,
          'vendor_name', v_receiving_record.vendor_name,
          'vendor_id', v_receiving_record.vendor_id,
          'branch_name', v_receiving_record.branch_name,
          'bill_amount', v_receiving_record.bill_amount,
          'bill_date', v_receiving_record.bill_date,
          'received_by', v_receiving_record.received_by_name,
          'due_date', v_due_date,
          'clearance_certificate_url', clearance_certificate_url_param
        )
      );
      
      -- Create notification recipient
      INSERT INTO notification_recipients (
        id,
        notification_id,
        user_id,
        is_read,
        created_at
      ) VALUES (
        gen_random_uuid(),
        v_notification_id,
        v_assigned_user_id,
        false,
        CURRENT_TIMESTAMP
      )
      ON CONFLICT (notification_id, user_id) DO NOTHING;
      
      v_notifications_sent := v_notifications_sent + 1;
    END IF;
    
  END LOOP;

  -- =======================================================
  -- STEP 6: RETURN SUCCESS RESPONSE
  -- =======================================================
  RETURN json_build_object(
    'success', true,
    'tasks_created', v_tasks_created,
    'notifications_sent', v_notifications_sent,
    'receiving_record_id', receiving_record_id_param,
    'certificate_url', clearance_certificate_url_param
  );

EXCEPTION 
  WHEN OTHERS THEN
    -- Catch any errors and return structured error response
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'error_code', 'INTERNAL_ERROR',
      'tasks_created', 0,
      'notifications_sent', 0
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- GRANT EXECUTE PERMISSIONS
-- =====================================================
GRANT EXECUTE ON FUNCTION process_clearance_certificate_generation TO authenticated;
GRANT EXECUTE ON FUNCTION process_clearance_certificate_generation TO service_role;

-- =====================================================
-- VERIFICATION QUERY
-- =====================================================
-- To verify the function was created:
-- SELECT proname, pg_get_functiondef(oid) 
-- FROM pg_proc 
-- WHERE proname = 'process_clearance_certificate_generation';
