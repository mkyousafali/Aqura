-- ERP Entry Tasks: satellite table + RPCs plugging into the existing generic
-- tasks / task_assignments / task_completions engine (same pattern already used
-- by vendor_payment_schedule: a dedicated table holding feature-specific fields,
-- linked via task_id/task_assignment_id, tagged via tasks.metadata so the shared
-- TaskCompletionModal (desktop + mobile) can recognize and sync it on completion).

-- ============================================================================
-- 1. Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.erp_entry_tasks (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id                 uuid NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    task_assignment_id      uuid REFERENCES public.task_assignments(id) ON DELETE SET NULL,
    branch_id               bigint REFERENCES public.branches(id),

    ledger_name             text NOT NULL,
    bill_number             text,
    voucher_number          text NOT NULL,
    bill_amount             numeric(15,2) NOT NULL,

    payment_type            text NOT NULL CHECK (payment_type IN ('cash', 'bank')),
    bank_ledger_id          bigint,
    bank_ledger_name        text,

    status                  text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),

    created_by              uuid NOT NULL REFERENCES public.users(id),
    created_by_name         text,
    created_at              timestamptz NOT NULL DEFAULT now(),

    completed_by            uuid REFERENCES public.users(id),
    completed_by_name       text,
    completed_at            timestamptz,
    payment_voucher_number  text,

    updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_erp_entry_tasks_task_id ON public.erp_entry_tasks(task_id);
CREATE INDEX IF NOT EXISTS idx_erp_entry_tasks_branch_id ON public.erp_entry_tasks(branch_id);
CREATE INDEX IF NOT EXISTS idx_erp_entry_tasks_status ON public.erp_entry_tasks(status);
CREATE INDEX IF NOT EXISTS idx_erp_entry_tasks_created_by ON public.erp_entry_tasks(created_by);
CREATE INDEX IF NOT EXISTS idx_erp_entry_tasks_created_at ON public.erp_entry_tasks(created_at DESC);

-- RLS enabled with no policies: the table is reachable only through the
-- SECURITY DEFINER RPCs below (RPC-only access), never directly via PostgREST.
ALTER TABLE public.erp_entry_tasks ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.erp_entry_tasks IS
  'ERP-specific fields for "ERP Entry" tasks (Send button on a PI row in ERP Ledgers). '
  'One row per task, linked via task_id/task_assignment_id into the generic tasks/task_assignments '
  'engine so the task shows up in My Tasks, mobile Tasks, and Branch Performance like any other task. '
  'Completion (payment_voucher_number) is written by complete_erp_entry_task(), called from the shared '
  'TaskCompletionModal when tasks.metadata->>''payment_type'' = ''erp_entry''.';

-- ============================================================================
-- 2. create_erp_entry_task — atomically creates the task + assignment +
--    erp_entry_tasks row + in-app/push notification.
-- ============================================================================

DROP FUNCTION IF EXISTS public.create_erp_entry_task(bigint, text, text, text, numeric, text, bigint, text, uuid, text);

CREATE OR REPLACE FUNCTION public.create_erp_entry_task(
    p_branch_id         bigint,
    p_ledger_name       text,
    p_bill_number       text,
    p_voucher_number    text,
    p_bill_amount       numeric,
    p_payment_type      text,
    p_bank_ledger_id    bigint,
    p_bank_ledger_name  text,
    p_created_by        uuid,
    p_created_by_name   text
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
        bill_amount, payment_type, bank_ledger_id, bank_ledger_name,
        status, created_by, created_by_name
    ) VALUES (
        v_task_id, v_assignment_id, p_branch_id, p_ledger_name, p_bill_number, p_voucher_number,
        p_bill_amount, p_payment_type, p_bank_ledger_id, p_bank_ledger_name,
        'pending', p_created_by, p_created_by_name
    ) RETURNING id INTO v_erp_entry_task_id;

    -- Tag the task so the shared TaskCompletionModal (desktop + mobile) recognizes it,
    -- exactly the way vendor_payment_schedule tasks are tagged with payment_type='vendor_payment'.
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
        -- Push is best-effort; the in-app notification row above already exists either way.
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

GRANT EXECUTE ON FUNCTION public.create_erp_entry_task(bigint, text, text, text, numeric, text, bigint, text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_erp_entry_task(bigint, text, text, text, numeric, text, bigint, text, uuid, text) TO anon;

-- ============================================================================
-- 3. complete_erp_entry_task — called from TaskCompletionModal's completion
--    sync block once the shared "ERP reference" field has been filled in.
-- ============================================================================

DROP FUNCTION IF EXISTS public.complete_erp_entry_task(uuid, text, uuid, text);

CREATE OR REPLACE FUNCTION public.complete_erp_entry_task(
    p_erp_entry_task_id  uuid,
    p_voucher_number     text,
    p_completed_by       uuid,
    p_completed_by_name  text
)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    v_status text;
BEGIN
    IF p_voucher_number IS NULL OR TRIM(p_voucher_number) = '' THEN
        RAISE EXCEPTION 'payment voucher number is required';
    END IF;

    SELECT status INTO v_status FROM erp_entry_tasks WHERE id = p_erp_entry_task_id;
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

    RETURN json_build_object('success', true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_erp_entry_task(uuid, text, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_erp_entry_task(uuid, text, uuid, text) TO anon;

-- ============================================================================
-- 4. get_erp_entry_tasks — feeds the ERP Entries window table.
-- ============================================================================

DROP FUNCTION IF EXISTS public.get_erp_entry_tasks(bigint, text, integer);

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
            e.ledger_name, e.bill_number, e.voucher_number, e.bill_amount,
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

GRANT EXECUTE ON FUNCTION public.get_erp_entry_tasks(bigint, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_erp_entry_tasks(bigint, text, integer) TO anon;
