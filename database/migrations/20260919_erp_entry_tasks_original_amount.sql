-- Keeps the original PI amount (as shown in the ledger) next to the editable bill_amount,
-- so the narration shown in the ERP Entries window can quote the original bill amount.

ALTER TABLE public.erp_entry_tasks
    ADD COLUMN IF NOT EXISTS original_bill_amount numeric(15,2);

-- Signature changes (new trailing param), so the old overload must go to avoid ambiguity.
DROP FUNCTION IF EXISTS public.create_erp_entry_task(bigint, text, text, text, numeric, text, bigint, text, uuid, text);
DROP FUNCTION IF EXISTS public.create_erp_entry_task(bigint, text, text, text, numeric, text, bigint, text, uuid, text, numeric);

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
        'medium', true, false, true,
        false, true, 'active'
    ) RETURNING id INTO v_task_id;

    INSERT INTO task_assignments (
        task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id,
        assigned_by, assigned_by_name, priority_override, status,
        require_task_finished, require_photo_upload, require_erp_reference
    ) VALUES (
        v_task_id, 'user', p_created_by, p_branch_id,
        p_created_by, p_created_by_name, 'medium', 'assigned',
        true, false, true
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
            'erp_entry_task_id', v_erp_entry_task_id, 'require_erp_reference', true
        )
    ) RETURNING id INTO v_notification_id;

    BEGIN
        PERFORM queue_push_notification(v_notification_id, 'specific_users', to_jsonb(ARRAY[p_created_by::text]));
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN json_build_object(
        'success', true,
        'task_id', v_task_id,
        'assignment_id', v_assignment_id,
        'erp_entry_task_id', v_erp_entry_task_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_erp_entry_task(bigint, text, text, text, numeric, text, bigint, text, uuid, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_erp_entry_task(bigint, text, text, text, numeric, text, bigint, text, uuid, text, numeric) TO anon;

-- Same signature as before; only the returned JSON gains original_bill_amount.
CREATE OR REPLACE FUNCTION public.get_erp_entry_tasks(
    p_branch_id  bigint DEFAULT NULL,
    p_status     text DEFAULT NULL,
    p_limit      integer DEFAULT 500
)
RETURNS json
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
    SELECT COALESCE(json_agg(row_to_json(r)), '[]'::json)
    FROM (
        SELECT
            e.id, e.status, e.branch_id,
            b.name_en AS branch_name_en, b.name_ar AS branch_name_ar,
            e.ledger_name, e.bill_number, e.voucher_number, e.bill_amount, e.original_bill_amount,
            e.payment_type, e.bank_ledger_name,
            e.created_by, e.created_by_name, e.created_at,
            e.payment_voucher_number, e.completed_by, e.completed_by_name, e.completed_at,
            e.task_id, e.task_assignment_id
        FROM erp_entry_tasks e
        LEFT JOIN branches b ON b.id = e.branch_id
        WHERE (p_branch_id IS NULL OR e.branch_id = p_branch_id)
          AND (p_status IS NULL OR e.status = p_status)
        ORDER BY e.created_at DESC
        LIMIT p_limit
    ) r;
$$;
