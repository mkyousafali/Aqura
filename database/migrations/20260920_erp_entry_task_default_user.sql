-- ERP Entry Task: per-branch default assignee + explicit assignee on create.
--
-- 1. branch_default_positions already holds "default user per branch" config (UNIQUE(branch_id),
--    user columns are uuid FKs to users(id) ON DELETE SET NULL), so the default Entry Task user is
--    one more column there rather than a new table. Managed from
--    Control Center > App Permissions > Default Entry Task Users.
-- 2. create_erp_entry_task gains p_assigned_to: the task assignment and its notification now go to
--    that user instead of the sender. The sender stays as assigned_by / created_by. There is no
--    fallback to the sender -- the caller must always pick an assignee.

ALTER TABLE public.branch_default_positions
    ADD COLUMN IF NOT EXISTS entry_task_user_id uuid REFERENCES public.users(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.branch_default_positions.entry_task_user_id IS
    'Default assignee for ERP Entry Tasks created for this branch (pre-selected in ERP Ledgers > Send). NULL = no default.';

-- Drop the previous signature so PostgREST does not see two overloads with defaults.
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
    p_original_bill_amount  numeric DEFAULT NULL,
    p_assigned_to           uuid DEFAULT NULL
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
    IF p_assigned_to IS NULL THEN
        RAISE EXCEPTION 'assignee is required';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_assigned_to AND status = 'active') THEN
        RAISE EXCEPTION 'assignee is not an active user';
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
        v_task_id, 'user', p_assigned_to, p_branch_id,
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
        'task_assigned', 'medium', 'specific_users', to_jsonb(ARRAY[p_assigned_to::text]),
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

GRANT EXECUTE ON FUNCTION public.create_erp_entry_task(bigint, text, text, text, numeric, text, bigint, text, uuid, text, numeric, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_erp_entry_task(bigint, text, text, text, numeric, text, bigint, text, uuid, text, numeric, uuid) TO anon;

NOTIFY pgrst, 'reload schema';
