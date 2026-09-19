-- The ERP reference number (CP/BP payment voucher no.) is no longer asked when closing the task
-- from My Tasks. It is entered in the ERP Entries window together with an "Entry done" checkbox,
-- which calls complete_erp_entry_task() below.

-- 1. Existing ERP entry tasks stop requiring an ERP reference at task-closing time.
UPDATE tasks SET require_erp_reference = false
WHERE metadata->>'payment_type' = 'erp_entry';

UPDATE task_assignments ta SET require_erp_reference = false
FROM erp_entry_tasks e
WHERE e.task_assignment_id = ta.id;

-- 2. New tasks are created without the requirement (same signature as before).
CREATE OR REPLACE FUNCTION public.create_erp_entry_task(
    p_branch_id             bigint,
    p_ledger_name           text,
    p_bill_number           text,
    p_voucher_number        text,
    p_bill_amount           numeric,
    p_payment_type          text,
    p_bank_ledger_id        bigint,
    p_bank_ledger_name      text,
    p_created_by            uuid,
    p_created_by_name       text,
    p_original_bill_amount  numeric DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_task_id            uuid;
    v_assignment_id      uuid;
    v_erp_entry_task_id  uuid;
    v_notification_id    uuid;
    v_title              text;
BEGIN
    IF p_payment_type NOT IN ('cash', 'bank') THEN
        RAISE EXCEPTION 'invalid payment type: %', p_payment_type;
    END IF;
    IF p_payment_type = 'bank' AND p_bank_ledger_id IS NULL THEN
        RAISE EXCEPTION 'bank account is required when payment type is bank';
    END IF;
    IF p_bill_amount IS NULL OR p_bill_amount <= 0 THEN
        RAISE EXCEPTION 'bill amount must be greater than zero';
    END IF;
    IF p_voucher_number IS NULL OR TRIM(p_voucher_number) = '' THEN
        RAISE EXCEPTION 'voucher number is required';
    END IF;

    v_title := 'ERP Entry: ' || p_ledger_name || CASE WHEN p_bill_number IS NOT NULL THEN ' (' || p_bill_number || ')' ELSE '' END;

    INSERT INTO tasks (
        title, description, created_by, created_by_name, created_by_role,
        priority, require_task_finished, require_photo_upload, require_erp_reference,
        can_escalate, can_reassign, status
    ) VALUES (
        v_title,
        'ERP Entry task for ledger "' || p_ledger_name || '", voucher ' || p_voucher_number ||
            CASE WHEN p_bill_number IS NOT NULL THEN ', bill ' || p_bill_number ELSE '' END || '.',
        p_created_by::text, p_created_by_name, 'User',
        'medium', true, false, false,
        false, true, 'active'
    ) RETURNING id INTO v_task_id;

    INSERT INTO task_assignments (
        task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id,
        assigned_by, assigned_by_name, priority_override, status,
        require_task_finished, require_photo_upload, require_erp_reference
    ) VALUES (
        v_task_id, 'user', p_created_by, p_branch_id,
        p_created_by, p_created_by_name, 'medium', 'assigned',
        true, false, false
    ) RETURNING id INTO v_assignment_id;

    INSERT INTO erp_entry_tasks (
        task_id, task_assignment_id, branch_id, ledger_name, bill_number, voucher_number,
        bill_amount, original_bill_amount, payment_type, bank_ledger_id, bank_ledger_name,
        status, created_by, created_by_name
    ) VALUES (
        v_task_id, v_assignment_id, p_branch_id, p_ledger_name, p_bill_number, p_voucher_number,
        p_bill_amount, COALESCE(p_original_bill_amount, p_bill_amount), p_payment_type, p_bank_ledger_id, p_bank_ledger_name,
        'pending', p_created_by, p_created_by_name
    ) RETURNING id INTO v_erp_entry_task_id;

    UPDATE tasks SET metadata = jsonb_build_object(
        'payment_type', 'erp_entry',
        'erp_entry_task_id', v_erp_entry_task_id,
        'task_assignment_id', v_assignment_id
    ) WHERE id = v_task_id;

    INSERT INTO notifications (
        title, message, title_en, title_ar, message_en, message_ar,
        type, priority, target_type, target_users,
        created_by, created_by_name, created_by_role, status, total_recipients,
        task_id, task_assignment_id, metadata
    ) VALUES (
        'ERP Entry Task | مهمة إدخال ERP',
        'You have an ERP Entry task. --- لديك مهمة إدخال ERP.',
        'ERP Entry Task', 'مهمة إدخال ERP',
        'You have an ERP Entry task.', 'لديك مهمة إدخال ERP.',
        'task_assigned', 'medium', 'specific_users', to_jsonb(ARRAY[p_created_by::text]),
        p_created_by::text, p_created_by_name, 'User', 'published', 1,
        v_task_id, v_assignment_id,
        jsonb_build_object(
            'task_id', v_task_id, 'task_assignment_id', v_assignment_id,
            'erp_entry_task_id', v_erp_entry_task_id, 'require_erp_reference', false
        )
    ) RETURNING id INTO v_notification_id;

    RETURN json_build_object(
        'success', true,
        'task_id', v_task_id,
        'assignment_id', v_assignment_id,
        'erp_entry_task_id', v_erp_entry_task_id,
        'notification_id', v_notification_id
    );
END;
$$;

-- 3. "Entry done": records the reference number on the entry AND closes the linked task
--    (if it is still open) so it doesn't linger in My Tasks / Branch Performance as pending.
CREATE OR REPLACE FUNCTION public.complete_erp_entry_task(
    p_erp_entry_task_id  uuid,
    p_voucher_number     text,
    p_completed_by       uuid,
    p_completed_by_name  text
)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_status         text;
    v_task_id        uuid;
    v_assignment_id  uuid;
BEGIN
    IF p_voucher_number IS NULL OR TRIM(p_voucher_number) = '' THEN
        RAISE EXCEPTION 'ERP reference number is required';
    END IF;

    SELECT status, task_id, task_assignment_id INTO v_status, v_task_id, v_assignment_id
    FROM erp_entry_tasks WHERE id = p_erp_entry_task_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'erp entry task not found';
    END IF;

    IF v_status = 'completed' THEN
        RETURN json_build_object('success', true, 'already_completed', true);
    END IF;

    UPDATE erp_entry_tasks SET
        status = 'completed',
        payment_voucher_number = TRIM(p_voucher_number),
        completed_by = p_completed_by,
        completed_by_name = p_completed_by_name,
        completed_at = now(),
        updated_at = now()
    WHERE id = p_erp_entry_task_id;

    IF v_assignment_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM task_assignments WHERE id = v_assignment_id AND status NOT IN ('completed', 'cancelled')
    ) THEN
        INSERT INTO task_completions (
            task_id, assignment_id, completed_by, completed_by_name,
            task_finished_completed, erp_reference_completed, erp_reference_number, completed_at
        ) VALUES (
            v_task_id, v_assignment_id, p_completed_by::text, p_completed_by_name,
            true, true, TRIM(p_voucher_number), now()
        );

        UPDATE task_assignments SET status = 'completed', completed_at = now() WHERE id = v_assignment_id;
    END IF;

    RETURN json_build_object('success', true);
END;
$$;
