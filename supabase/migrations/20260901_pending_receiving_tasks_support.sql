-- Support clearance-certificate task generation for records that live in
-- pending_receiving_records instead of receiving_records.
--
-- Background: Start Receiving now lets the user pick a bill type on an intro screen.
-- "Original Bill" keeps posting to receiving_records exactly as before (untouched).
-- Any other choice posts to pending_receiving_records instead — but the user still
-- wants clearance-certificate generation and task assignment to work normally for
-- those too. receiving_tasks.receiving_record_id can therefore now point at a row in
-- EITHER table, so:
--
--   1. Drop the FK that pinned receiving_tasks.receiving_record_id to receiving_records
--      only (kept: the plain column and its existing btree index). No app code deletes
--      rows from receiving_records today, so the lost ON DELETE CASCADE is not
--      currently exercised.
--   2. Add process_pending_clearance_certificate_generation(...) — an exact functional
--      copy of process_clearance_certificate_generation(...), reading from
--      pending_receiving_records instead of receiving_records. The original function is
--      untouched.
--   3. Add get_tasks_for_pending_receiving_record(...) — an exact functional copy of
--      get_tasks_for_receiving_record(...), joined against pending_receiving_records
--      instead of receiving_records. The original function is untouched.

-- =======================================================
-- 1. Relax the FK so receiving_tasks can reference either parent table
-- =======================================================
ALTER TABLE public.receiving_tasks
  DROP CONSTRAINT IF EXISTS receiving_tasks_receiving_record_id_fkey;

-- =======================================================
-- 2. process_pending_clearance_certificate_generation(...)
-- =======================================================
CREATE OR REPLACE FUNCTION public.process_pending_clearance_certificate_generation(
  receiving_record_id_param uuid,
  clearance_certificate_url_param text,
  generated_by_user_id uuid,
  generated_by_name text DEFAULT NULL::text,
  generated_by_role text DEFAULT NULL::text
)
RETURNS json
LANGUAGE plpgsql
AS $function$
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
  v_user_idx INT;
  v_array_len INT;
BEGIN

  -- STEP 1: PREVENT DUPLICATE TASK CREATION
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

  -- STEP 2: LOAD PENDING RECEIVING RECORD WITH RELATED DATA
  SELECT
    rr.*,
    v.vendor_name,
    b.name_en as branch_name,
    COALESCE(emp.name, u.username) as received_by_name
  INTO v_receiving_record
  FROM pending_receiving_records rr
  LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  LEFT JOIN users u ON u.id = rr.user_id
  LEFT JOIN hr_employees emp ON emp.id = u.employee_id
  WHERE rr.id = receiving_record_id_param;

  IF NOT FOUND THEN
    RETURN json_build_object(
      'success', false,
      'error', 'Pending receiving record not found',
      'error_code', 'RECORD_NOT_FOUND',
      'tasks_created', 0,
      'notifications_sent', 0
    );
  END IF;

  -- STEP 3: CREATE TASKS FROM TEMPLATES
  FOR v_template IN
    SELECT * FROM receiving_task_templates
    ORDER BY priority DESC, id ASC
  LOOP

    v_title := v_template.title_template;
    v_title := REPLACE(v_title, '{bill_number}', COALESCE(v_receiving_record.bill_number, 'N/A'));
    v_title := REPLACE(v_title, '{vendor_name}', COALESCE(v_receiving_record.vendor_name, 'Unknown Vendor'));
    v_title := REPLACE(v_title, '{branch_name}', COALESCE(v_receiving_record.branch_name, 'Unknown Branch'));

    v_description := v_template.description_template;
    v_description := REPLACE(v_description, '{bill_number}', COALESCE(v_receiving_record.bill_number, 'N/A'));
    v_description := REPLACE(v_description, '{vendor_name}', COALESCE(v_receiving_record.vendor_name, 'Unknown Vendor'));
    v_description := REPLACE(v_description, '{branch_name}', COALESCE(v_receiving_record.branch_name, 'Unknown Branch'));
    v_description := REPLACE(v_description, '{vendor_id}', COALESCE(v_receiving_record.vendor_id::TEXT, 'N/A'));
    v_description := REPLACE(v_description, '{bill_amount}', COALESCE(v_receiving_record.bill_amount::TEXT, 'N/A'));
    v_description := REPLACE(v_description, '{bill_date}', COALESCE(TO_CHAR(v_receiving_record.bill_date, 'YYYY-MM-DD'), 'N/A'));
    v_description := REPLACE(v_description, '{received_by}', COALESCE(v_receiving_record.received_by_name, 'Unknown'));
    v_description := REPLACE(v_description, '{certificate_url}', COALESCE(clearance_certificate_url_param, 'Not Available'));

    v_due_date := (NOW() AT TIME ZONE 'UTC' AT TIME ZONE '+03:00') + (v_template.deadline_hours || ' hours')::INTERVAL;
    v_description := REPLACE(v_description, '{deadline}', TO_CHAR(v_due_date, 'YYYY-MM-DD HH24:MI') || ' UTC+3');

    IF v_template.role_type IN ('night_supervisor', 'warehouse_handler', 'shelf_stocker') THEN
      DECLARE
        v_user_ids UUID[];
      BEGIN
        CASE v_template.role_type
          WHEN 'night_supervisor' THEN
            v_user_ids := v_receiving_record.night_supervisor_user_ids;
          WHEN 'warehouse_handler' THEN
            v_user_ids := v_receiving_record.warehouse_handler_user_ids;
          WHEN 'shelf_stocker' THEN
            v_user_ids := v_receiving_record.shelf_stocker_user_ids;
        END CASE;

        IF v_user_ids IS NOT NULL AND array_length(v_user_ids, 1) > 0 THEN
          FOR v_user_idx IN 1..array_length(v_user_ids, 1) LOOP
            v_assigned_user_id := v_user_ids[v_user_idx];

            v_task_id := gen_random_uuid();

            INSERT INTO receiving_tasks (
              id, receiving_record_id, template_id, role_type, assigned_user_id,
              title, description, priority, due_date, task_status, task_completed,
              clearance_certificate_url, created_at, updated_at
            ) VALUES (
              v_task_id, receiving_record_id_param, v_template.id, v_template.role_type,
              v_assigned_user_id, v_title, v_description, v_template.priority,
              v_due_date, 'pending', false, clearance_certificate_url_param,
              CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            );

            v_tasks_created := v_tasks_created + 1;

            IF v_assigned_user_id IS NOT NULL THEN
              v_notification_id := gen_random_uuid();

              INSERT INTO notifications (
                id, title, message, type, priority, created_by, created_by_name,
                target_users, target_type, status, created_at, sent_at, metadata
              ) VALUES (
                v_notification_id,
                'New Receiving Task Assigned',
                E'⚠️ New Task Assigned: A new task has been assigned to you: ' || v_title ||
                ' Branch: ' || COALESCE(v_receiving_record.branch_name, 'Unknown') ||
                ' Vendor: ' || COALESCE(v_receiving_record.vendor_name, 'Unknown') ||
                ' (ID: ' || COALESCE(v_receiving_record.vendor_id::TEXT, 'N/A') || ')' ||
                ' Bill Amount: ' || COALESCE(v_receiving_record.bill_amount::TEXT, 'N/A') ||
                ' Bill Number: ' || COALESCE(v_receiving_record.bill_number, 'N/A') ||
                ' Received Date: ' || COALESCE(TO_CHAR(v_receiving_record.bill_date, 'YYYY-MM-DD'), 'N/A') ||
                ' Received By: ' || COALESCE(v_receiving_record.received_by_name, 'Unknown') ||
                ' Deadline: ' || TO_CHAR(v_due_date, 'YYYY-MM-DD HH24:MI') || ' (24 hours)' ||
                ' Please start the delivery placement process and manage the team accordingly.',
                'task', v_template.priority, generated_by_user_id,
                COALESCE(generated_by_name, 'System'),
                jsonb_build_array(v_assigned_user_id::text),
                'specific_users', 'published', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
                jsonb_build_object(
                  'task_id', v_task_id, 'receiving_record_id', receiving_record_id_param,
                  'role_type', v_template.role_type, 'bill_number', v_receiving_record.bill_number,
                  'vendor_name', v_receiving_record.vendor_name, 'vendor_id', v_receiving_record.vendor_id,
                  'branch_name', v_receiving_record.branch_name, 'bill_amount', v_receiving_record.bill_amount,
                  'bill_date', v_receiving_record.bill_date, 'received_by', v_receiving_record.received_by_name,
                  'due_date', v_due_date, 'clearance_certificate_url', clearance_certificate_url_param
                )
              );

              INSERT INTO notification_recipients (id, notification_id, user_id, is_read, created_at)
              VALUES (gen_random_uuid(), v_notification_id, v_assigned_user_id, false, CURRENT_TIMESTAMP)
              ON CONFLICT (notification_id, user_id) DO NOTHING;

              v_notifications_sent := v_notifications_sent + 1;
            END IF;

          END LOOP;
        END IF;
      END;

    ELSE
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
        ELSE
          v_assigned_user_id := NULL;
      END CASE;

      v_task_id := gen_random_uuid();

      INSERT INTO receiving_tasks (
        id, receiving_record_id, template_id, role_type, assigned_user_id,
        title, description, priority, due_date, task_status, task_completed,
        clearance_certificate_url, created_at, updated_at
      ) VALUES (
        v_task_id, receiving_record_id_param, v_template.id, v_template.role_type,
        v_assigned_user_id, v_title, v_description, v_template.priority,
        v_due_date, 'pending', false, clearance_certificate_url_param,
        CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      );

      v_tasks_created := v_tasks_created + 1;

      IF v_assigned_user_id IS NOT NULL THEN
        v_notification_id := gen_random_uuid();

        INSERT INTO notifications (
          id, title, message, type, priority, created_by, created_by_name,
          target_users, target_type, status, created_at, sent_at, metadata
        ) VALUES (
          v_notification_id,
          'New Receiving Task Assigned',
          E'⚠️ New Task Assigned: A new task has been assigned to you: ' || v_title ||
          ' Branch: ' || COALESCE(v_receiving_record.branch_name, 'Unknown') ||
          ' Vendor: ' || COALESCE(v_receiving_record.vendor_name, 'Unknown') ||
          ' (ID: ' || COALESCE(v_receiving_record.vendor_id::TEXT, 'N/A') || ')' ||
          ' Bill Amount: ' || COALESCE(v_receiving_record.bill_amount::TEXT, 'N/A') ||
          ' Bill Number: ' || COALESCE(v_receiving_record.bill_number, 'N/A') ||
          ' Received Date: ' || COALESCE(TO_CHAR(v_receiving_record.bill_date, 'YYYY-MM-DD'), 'N/A') ||
          ' Received By: ' || COALESCE(v_receiving_record.received_by_name, 'Unknown') ||
          ' Deadline: ' || TO_CHAR(v_due_date, 'YYYY-MM-DD HH24:MI') || ' (24 hours)' ||
          ' Please start the delivery placement process and manage the team accordingly.',
          'task', v_template.priority, generated_by_user_id,
          COALESCE(generated_by_name, 'System'),
          jsonb_build_array(v_assigned_user_id::text),
          'specific_users', 'published', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP,
          jsonb_build_object(
            'task_id', v_task_id, 'receiving_record_id', receiving_record_id_param,
            'role_type', v_template.role_type, 'bill_number', v_receiving_record.bill_number,
            'vendor_name', v_receiving_record.vendor_name, 'vendor_id', v_receiving_record.vendor_id,
            'branch_name', v_receiving_record.branch_name, 'bill_amount', v_receiving_record.bill_amount,
            'bill_date', v_receiving_record.bill_date, 'received_by', v_receiving_record.received_by_name,
            'due_date', v_due_date, 'clearance_certificate_url', clearance_certificate_url_param
          )
        );

        INSERT INTO notification_recipients (id, notification_id, user_id, is_read, created_at)
        VALUES (gen_random_uuid(), v_notification_id, v_assigned_user_id, false, CURRENT_TIMESTAMP)
        ON CONFLICT (notification_id, user_id) DO NOTHING;

        v_notifications_sent := v_notifications_sent + 1;
      END IF;

    END IF;

  END LOOP;

  RETURN json_build_object(
    'success', true,
    'tasks_created', v_tasks_created,
    'notifications_sent', v_notifications_sent,
    'receiving_record_id', receiving_record_id_param,
    'certificate_url', clearance_certificate_url_param
  );

EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'error_code', 'INTERNAL_ERROR',
      'tasks_created', 0,
      'notifications_sent', 0
    );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.process_pending_clearance_certificate_generation(uuid, text, uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.process_pending_clearance_certificate_generation(uuid, text, uuid, text, text) TO anon;
GRANT EXECUTE ON FUNCTION public.process_pending_clearance_certificate_generation(uuid, text, uuid, text, text) TO service_role;

-- =======================================================
-- 3. get_tasks_for_pending_receiving_record(...)
-- =======================================================
CREATE OR REPLACE FUNCTION public.get_tasks_for_pending_receiving_record(receiving_record_id_param uuid)
RETURNS TABLE(
  task_id uuid, receiving_record_id uuid, role_type text, title text, description text,
  priority text, task_status text, task_completed boolean, due_date timestamp with time zone,
  created_at timestamp with time zone, completed_at timestamp with time zone, completed_by_user_id uuid,
  assigned_user_id uuid, requires_erp_reference boolean, requires_original_bill_upload boolean,
  erp_reference_number text, original_bill_uploaded boolean, original_bill_file_path text,
  clearance_certificate_url text, is_overdue boolean, days_until_due integer,
  bill_number text, vendor_name text, branch_name text
)
LANGUAGE plpgsql
AS $function$
BEGIN
  RETURN QUERY
  SELECT
    rt.id AS task_id,
    rt.receiving_record_id,
    rt.role_type::TEXT,
    rt.title,
    rt.description,
    rt.priority::TEXT,
    rt.task_status::TEXT,
    rt.task_completed,
    rt.due_date,
    rt.created_at,
    rt.completed_at,
    rt.completed_by_user_id,
    rt.assigned_user_id,
    rt.requires_erp_reference,
    rt.requires_original_bill_upload,
    rt.erp_reference_number::TEXT,
    rt.original_bill_uploaded,
    rt.original_bill_file_path,
    rt.clearance_certificate_url,
    CASE
      WHEN rt.task_completed = false AND rt.due_date < NOW() THEN true
      ELSE false
    END AS is_overdue,
    CASE
      WHEN rt.task_completed = false THEN
        EXTRACT(DAY FROM (rt.due_date - NOW()))::INTEGER
      ELSE
        NULL
    END AS days_until_due,
    rr.bill_number::TEXT,
    v.vendor_name::TEXT,
    b.name_en::TEXT AS branch_name
  FROM receiving_tasks rt
  LEFT JOIN pending_receiving_records rr ON rr.id = rt.receiving_record_id
  LEFT JOIN vendors v ON v.erp_vendor_id = rr.vendor_id AND v.branch_id = rr.branch_id
  LEFT JOIN branches b ON b.id = rr.branch_id
  WHERE rt.receiving_record_id = receiving_record_id_param
  ORDER BY
    CASE rt.task_status
      WHEN 'pending' THEN 1
      WHEN 'in_progress' THEN 2
      WHEN 'completed' THEN 3
      ELSE 4
    END,
    rt.due_date ASC;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_tasks_for_pending_receiving_record(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_tasks_for_pending_receiving_record(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_tasks_for_pending_receiving_record(uuid) TO service_role;
