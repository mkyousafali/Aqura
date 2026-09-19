-- ERP entries can now also be settled by a Journal Voucher (JV), in addition to cash (CP) and
-- bank (BP). For JV the credit side is any ledger of the branch chosen in the Send popup; it is
-- stored in the existing bank_ledger_id / bank_ledger_name columns, which now mean "credit account"
-- for both 'bank' and 'jv' entries.

ALTER TABLE public.erp_entry_tasks DROP CONSTRAINT IF EXISTS erp_entry_tasks_payment_type_check;
ALTER TABLE public.erp_entry_tasks
    ADD CONSTRAINT erp_entry_tasks_payment_type_check CHECK (payment_type IN ('cash', 'bank', 'jv'));

COMMENT ON COLUMN public.erp_entry_tasks.bank_ledger_id IS
  'Credit-side ERP ledger id: the bank account for payment_type=bank, the chosen credit account for payment_type=jv; NULL for cash.';

-- Same signature as before; only the validation changes.
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
    IF p_payment_type NOT IN ('cash', 'bank', 'jv') THEN
        RAISE EXCEPTION 'invalid payment type: %', p_payment_type;
    END IF;
    IF p_payment_type IN ('bank', 'jv') AND p_bank_ledger_id IS NULL THEN
        RAISE EXCEPTION 'a credit account is required when payment type is bank or jv';
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
