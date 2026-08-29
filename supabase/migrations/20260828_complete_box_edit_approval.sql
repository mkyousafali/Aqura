-- Complete Box Edit Approval: OTP-gated editing of a closed/closing box,
-- with a dedicated before/after audit trail and approver email notifications.
--
-- Design (confirmed with the user before building):
--  - Master Admin assigns one or more "approvers" (complete_box_approvers).
--  - Clicking Edit in CompleteBox sends a 6-digit OTP by email to ALL active
--    approvers; ANY one valid code unlocks editing (not all-of-them).
--  - The moment a code is verified, the full current record is snapshotted
--    as "before" into complete_box_edit_history (status='pending').
--  - Auto-save is replaced by an explicit Save action: Save writes the
--    "after" snapshot into the same history row (status='saved') and emails
--    every approver who was sent an OTP for this session a before/after
--    change summary. Cancelling (or abandoning without saving) instead marks
--    the row 'cancelled' and emails those approvers that no changes were made.
--  - Reuses the same OTP mechanism the Aqura PC Lock Guard app already uses
--    (email_otp style: 6-digit code, bcrypt-hashed, 5-minute expiry) and the
--    same email_messages/email_message_recipients/email_queue pipeline as
--    generate_and_send_email_otp, but scoped to (box_operation, approver)
--    pairs instead of a single self-verifying user.

-- ============================================================
-- 1. Tables
-- ============================================================

CREATE TABLE public.complete_box_approvers (
    user_id uuid NOT NULL PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    is_active boolean NOT NULL DEFAULT true,
    assigned_by uuid REFERENCES public.users(id),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.complete_box_approvers IS
    'Users who can approve editing a Complete Box record via OTP. Managed by Master Admin from the "Complete Box Approvers" tab in Denomination Manager.';

CREATE TABLE public.complete_box_edit_otp_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    box_operation_id uuid NOT NULL REFERENCES public.box_operations(id) ON DELETE CASCADE,
    approver_user_id uuid NOT NULL REFERENCES public.users(id),
    otp_hash text NOT NULL,
    masked_email text,
    is_used boolean NOT NULL DEFAULT false,
    used_at timestamp with time zone,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.complete_box_edit_otp_requests IS
    'One row per approver per edit-request send. Any one approver''s unused, unexpired code approves editing for that box_operation_id.';

CREATE INDEX complete_box_edit_otp_requests_box_idx
    ON public.complete_box_edit_otp_requests (box_operation_id, is_used, expires_at);

CREATE TABLE public.complete_box_edit_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    box_operation_id uuid NOT NULL REFERENCES public.box_operations(id) ON DELETE CASCADE,
    requested_by uuid REFERENCES public.users(id),
    approved_by uuid REFERENCES public.users(id),
    before_data jsonb,
    after_data jsonb,
    status text NOT NULL DEFAULT 'pending' CHECK (status = ANY (ARRAY['pending'::text, 'saved'::text, 'cancelled'::text])),
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    resolved_at timestamp with time zone
);

COMMENT ON TABLE public.complete_box_edit_history IS
    'One row per OTP-approved edit session on a Complete Box record. before_data is captured the instant the OTP is verified; after_data is captured only if Save is pressed (status=saved) — a cancelled/abandoned session leaves after_data null.';

CREATE INDEX complete_box_edit_history_box_idx
    ON public.complete_box_edit_history (box_operation_id, created_at DESC);

ALTER TABLE public.complete_box_approvers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complete_box_edit_otp_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complete_box_edit_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to complete_box_approvers"
    ON public.complete_box_approvers USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to complete_box_edit_otp_requests"
    ON public.complete_box_edit_otp_requests USING (true) WITH CHECK (true);
CREATE POLICY "Allow all access to complete_box_edit_history"
    ON public.complete_box_edit_history USING (true) WITH CHECK (true);

-- ============================================================
-- 2. Approver management RPC (Master-Admin-only write, matching the
--    upsert_button_permission / salary-statement-permission convention)
-- ============================================================

CREATE FUNCTION public.upsert_complete_box_approver(
    p_requesting_user_id uuid,
    p_target_user_id uuid,
    p_is_active boolean
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_is_master_admin boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    IF NOT COALESCE(v_is_master_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin only');
    END IF;

    INSERT INTO public.complete_box_approvers (user_id, is_active, assigned_by, updated_at)
    VALUES (p_target_user_id, p_is_active, p_requesting_user_id, now())
    ON CONFLICT (user_id)
    DO UPDATE SET is_active = excluded.is_active, assigned_by = excluded.assigned_by, updated_at = now();

    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

CREATE FUNCTION public.remove_complete_box_approver(
    p_requesting_user_id uuid,
    p_target_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_is_master_admin boolean;
BEGIN
    SELECT is_master_admin INTO v_is_master_admin FROM public.users WHERE id = p_requesting_user_id;
    IF NOT COALESCE(v_is_master_admin, false) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Access denied: Master Admin only');
    END IF;

    DELETE FROM public.complete_box_approvers WHERE user_id = p_target_user_id;
    RETURN jsonb_build_object('success', true);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- 3. OTP send — emails every active approver, mirroring
--    generate_and_send_email_otp's queue-composition approach.
-- ============================================================

CREATE FUNCTION public.send_complete_box_edit_otp(
    p_box_operation_id uuid,
    p_requested_by uuid,
    p_box_number text DEFAULT NULL,
    p_branch_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_approver RECORD;
    v_otp text;
    v_otp_hash text;
    v_masked text;
    v_expires_at timestamptz := now() + interval '5 minutes';
    v_account_id uuid;
    v_account_email text;
    v_account_name text;
    v_html text;
    v_msg_id uuid;
    v_queue_id uuid;
    v_queue_ids jsonb := '[]'::jsonb;
    v_sent_count int := 0;
    v_context text := trim(both ' - ' from coalesce('Box #' || p_box_number, '') || coalesce(' - ' || p_branch_name, ''));
BEGIN
    SELECT id, email_address, from_name INTO v_account_id, v_account_email, v_account_name
    FROM public.email_accounts
    WHERE is_active = true AND send_enabled = true AND default_for_otp = true
    LIMIT 1;

    IF v_account_id IS NULL THEN
        SELECT id, email_address, from_name INTO v_account_id, v_account_email, v_account_name
        FROM public.email_accounts
        WHERE is_active = true AND send_enabled = true
        LIMIT 1;
    END IF;

    IF v_account_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'No email account configured for sending');
    END IF;

    -- Invalidate any still-pending OTPs from a previous request for this box
    UPDATE public.complete_box_edit_otp_requests
    SET is_used = true, used_at = now()
    WHERE box_operation_id = p_box_operation_id AND is_used = false;

    FOR v_approver IN
        SELECT ca.user_id, e.email, e.name_en
        FROM public.complete_box_approvers ca
        JOIN public.hr_employee_master e ON e.user_id = ca.user_id
        WHERE ca.is_active = true AND e.email IS NOT NULL AND e.email <> ''
    LOOP
        v_otp := lpad(floor(random() * 1000000)::int::text, 6, '0');
        v_otp_hash := extensions.crypt(v_otp, extensions.gen_salt('bf'));
        v_masked := substring(v_approver.email from 1 for 3) || '****@' || split_part(v_approver.email, '@', 2);

        INSERT INTO public.complete_box_edit_otp_requests (box_operation_id, approver_user_id, otp_hash, masked_email, expires_at)
        VALUES (p_box_operation_id, v_approver.user_id, v_otp_hash, v_masked, v_expires_at);

        v_html := '<div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:30px;">'
            || '<div style="text-align:center;margin-bottom:24px;"><h2 style="color:#059669;margin:0;">Aqura</h2>'
            || '<p style="color:#6b7280;font-size:14px;">Complete Box Edit Approval</p></div>'
            || '<p style="color:#374151;font-size:14px;">A request was made to edit a closing box record'
            || CASE WHEN v_context <> '' THEN ' (' || v_context || ')' ELSE '' END || '.</p>'
            || '<div style="background:#f0fdf4;border:2px solid #059669;border-radius:12px;padding:24px;text-align:center;margin-bottom:20px;">'
            || '<p style="color:#374151;font-size:14px;margin:0 0 8px;">Approval code:</p>'
            || '<div style="font-size:36px;font-weight:700;letter-spacing:8px;color:#059669;margin:12px 0;">' || v_otp || '</div>'
            || '<p style="color:#6b7280;font-size:12px;margin:8px 0 0;">Expires in 5 minutes</p></div>'
            || '<p style="color:#9ca3af;font-size:11px;text-align:center;">Only share this code with the person who should be allowed to make this edit. If you did not expect this request, contact your administrator.</p>'
            || '</div>';

        INSERT INTO public.email_messages (
            email_account_id, direction, status, subject, text_body, html_body,
            priority, from_address, from_name
        ) VALUES (
            v_account_id, 'outgoing', 'queued',
            'Aqura - Box Edit Approval Code' || CASE WHEN v_context <> '' THEN ' (' || v_context || ')' ELSE '' END,
            'Approval code: ' || v_otp || E'\nExpires in 5 minutes.\nOnly share this code with the person who should be allowed to make this edit.',
            v_html, 'critical', v_account_email, COALESCE(v_account_name, 'Aqura')
        ) RETURNING id INTO v_msg_id;

        INSERT INTO public.email_message_recipients (email_message_id, recipient_type, email_address, display_name)
        VALUES (v_msg_id, 'to', v_approver.email, COALESCE(v_approver.name_en, ''));

        INSERT INTO public.email_queue (queue_type, priority, email_account_id, email_message_id, status, available_at, maximum_attempts)
        VALUES ('normal', 1, v_account_id, v_msg_id, 'pending', now(), 3)
        RETURNING id INTO v_queue_id;

        v_queue_ids := v_queue_ids || to_jsonb(v_queue_id);
        v_sent_count := v_sent_count + 1;
    END LOOP;

    IF v_sent_count = 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'No active approvers with an email on file');
    END IF;

    RETURN jsonb_build_object('success', true, 'queue_ids', v_queue_ids, 'approver_count', v_sent_count, 'expires_in_seconds', 300);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- 4. OTP verify — any one approver's valid code approves the session,
--    captures the Before-Edit snapshot.
-- ============================================================

CREATE FUNCTION public.verify_complete_box_edit_otp(
    p_box_operation_id uuid,
    p_requested_by uuid,
    p_otp text,
    p_before_data jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_row RECORD;
    v_matched RECORD;
    v_history_id uuid;
BEGIN
    IF p_otp IS NULL OR length(p_otp) <> 6 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid OTP format');
    END IF;

    FOR v_row IN
        SELECT * FROM public.complete_box_edit_otp_requests
        WHERE box_operation_id = p_box_operation_id AND is_used = false AND expires_at > now()
    LOOP
        IF v_row.otp_hash = extensions.crypt(p_otp, v_row.otp_hash) THEN
            v_matched := v_row;
            EXIT;
        END IF;
    END LOOP;

    IF v_matched IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Incorrect or expired verification code');
    END IF;

    -- The matched code, and every other still-pending code for this box, are
    -- consumed together — one approval is enough, and it closes the window
    -- for a second, unrelated code to be used later.
    UPDATE public.complete_box_edit_otp_requests
    SET is_used = true, used_at = now()
    WHERE box_operation_id = p_box_operation_id AND is_used = false;

    INSERT INTO public.complete_box_edit_history (box_operation_id, requested_by, approved_by, before_data, status)
    VALUES (p_box_operation_id, p_requested_by, v_matched.approver_user_id, p_before_data, 'pending')
    RETURNING id INTO v_history_id;

    RETURN jsonb_build_object('success', true, 'history_id', v_history_id, 'approved_by', v_matched.approver_user_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;

-- ============================================================
-- 5. Resolve (Save or Cancel) — records the outcome and emails every
--    approver who was sent an OTP for this box's most recent request.
-- ============================================================

CREATE FUNCTION public.resolve_complete_box_edit(
    p_history_id uuid,
    p_status text,
    p_after_data jsonb DEFAULT NULL,
    p_box_number text DEFAULT NULL,
    p_branch_name text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
    v_history RECORD;
    v_approver RECORD;
    v_key text;
    v_before_val jsonb;
    v_after_val jsonb;
    v_diff_rows text := '';
    v_diff_count int := 0;
    v_account_id uuid;
    v_account_email text;
    v_account_name text;
    v_html text;
    v_subject text;
    v_msg_id uuid;
    v_queue_id uuid;
    v_queue_ids jsonb := '[]'::jsonb;
    v_context text;
BEGIN
    IF p_status NOT IN ('saved', 'cancelled') THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid status');
    END IF;

    UPDATE public.complete_box_edit_history
    SET status = p_status,
        after_data = CASE WHEN p_status = 'saved' THEN p_after_data ELSE after_data END,
        resolved_at = now()
    WHERE id = p_history_id AND status = 'pending'
    RETURNING * INTO v_history;

    IF v_history IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Edit session not found or already resolved');
    END IF;

    v_context := trim(both ' - ' from coalesce('Box #' || p_box_number, '') || coalesce(' - ' || p_branch_name, ''));

    -- Build a human-readable diff of top-level fields that actually changed.
    -- (complete_details is a flat-ish record of scalars/small objects; a
    -- top-level compare is enough to flag which section changed even where
    -- a sub-object like closing_counts differs internally.)
    IF p_status = 'saved' THEN
        FOR v_key, v_before_val, v_after_val IN
            SELECT COALESCE(b.key, a.key), b.value, a.value
            FROM jsonb_each(COALESCE(v_history.before_data, '{}'::jsonb)) b
            FULL OUTER JOIN jsonb_each(COALESCE(v_history.after_data, '{}'::jsonb)) a ON b.key = a.key
        LOOP
            IF v_before_val IS DISTINCT FROM v_after_val THEN
                v_diff_count := v_diff_count + 1;
                v_diff_rows := v_diff_rows || format(
                    '<tr><td style="padding:6px 10px;border-bottom:1px solid #e5e7eb;font-weight:600;color:#374151;">%s</td>' ||
                    '<td style="padding:6px 10px;border-bottom:1px solid #e5e7eb;color:#dc2626;">%s</td>' ||
                    '<td style="padding:6px 10px;border-bottom:1px solid #e5e7eb;color:#059669;font-weight:600;">%s</td></tr>',
                    v_key,
                    COALESCE(v_before_val #>> '{}', '—'),
                    COALESCE(v_after_val #>> '{}', '—')
                );
            END IF;
        END LOOP;
    END IF;

    SELECT id, email_address, from_name INTO v_account_id, v_account_email, v_account_name
    FROM public.email_accounts WHERE is_active = true AND send_enabled = true AND default_for_otp = true LIMIT 1;
    IF v_account_id IS NULL THEN
        SELECT id, email_address, from_name INTO v_account_id, v_account_email, v_account_name
        FROM public.email_accounts WHERE is_active = true AND send_enabled = true LIMIT 1;
    END IF;
    IF v_account_id IS NULL THEN
        RETURN jsonb_build_object('success', true, 'warning', 'Resolved, but no email account configured to notify approvers');
    END IF;

    IF p_status = 'saved' THEN
        v_subject := 'Aqura - Box Edit Saved' || CASE WHEN v_context <> '' THEN ' (' || v_context || ')' ELSE '' END;
        v_html := '<div style="font-family:Arial,sans-serif;max-width:560px;margin:0 auto;padding:30px;">'
            || '<div style="text-align:center;margin-bottom:20px;"><h2 style="color:#059669;margin:0;">Aqura</h2>'
            || '<p style="color:#6b7280;font-size:14px;">Box Edit Saved' || CASE WHEN v_context <> '' THEN ' — ' || v_context ELSE '' END || '</p></div>'
            || CASE WHEN v_diff_count = 0
                THEN '<p style="color:#6b7280;font-size:13px;">The edit was saved, but no field values actually changed.</p>'
                ELSE '<table style="width:100%;border-collapse:collapse;font-size:13px;">'
                    || '<tr style="background:#f9fafb;"><th style="padding:6px 10px;text-align:left;">Field</th><th style="padding:6px 10px;text-align:left;">Before</th><th style="padding:6px 10px;text-align:left;">After</th></tr>'
                    || v_diff_rows || '</table>'
            END
            || '</div>';
    ELSE
        v_subject := 'Aqura - Box Edit Cancelled' || CASE WHEN v_context <> '' THEN ' (' || v_context || ')' ELSE '' END;
        v_html := '<div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;padding:30px;">'
            || '<div style="text-align:center;margin-bottom:20px;"><h2 style="color:#6b7280;margin:0;">Aqura</h2>'
            || '<p style="color:#6b7280;font-size:14px;">Box Edit Cancelled' || CASE WHEN v_context <> '' THEN ' — ' || v_context ELSE '' END || '</p></div>'
            || '<p style="color:#374151;font-size:14px;">No changes were made in that session — the edit request was cancelled (or abandoned) before anything was saved.</p>'
            || '</div>';
    END IF;

    FOR v_approver IN
        SELECT DISTINCT r.approver_user_id, e.email, e.name_en
        FROM public.complete_box_edit_otp_requests r
        JOIN public.hr_employee_master e ON e.user_id = r.approver_user_id
        WHERE r.box_operation_id = v_history.box_operation_id
          AND r.created_at >= v_history.created_at - interval '15 minutes'
          AND e.email IS NOT NULL AND e.email <> ''
    LOOP
        INSERT INTO public.email_messages (
            email_account_id, direction, status, subject, text_body, html_body,
            priority, from_address, from_name
        ) VALUES (
            v_account_id, 'outgoing', 'queued', v_subject,
            CASE WHEN p_status = 'saved' THEN 'A box edit was saved. ' || v_diff_count || ' field(s) changed.'
                 ELSE 'A box edit request was cancelled — no changes were made.' END,
            v_html, 'normal', v_account_email, COALESCE(v_account_name, 'Aqura')
        ) RETURNING id INTO v_msg_id;

        INSERT INTO public.email_message_recipients (email_message_id, recipient_type, email_address, display_name)
        VALUES (v_msg_id, 'to', v_approver.email, COALESCE(v_approver.name_en, ''));

        INSERT INTO public.email_queue (queue_type, priority, email_account_id, email_message_id, status, available_at, maximum_attempts)
        VALUES ('normal', 1, v_account_id, v_msg_id, 'pending', now(), 3)
        RETURNING id INTO v_queue_id;

        v_queue_ids := v_queue_ids || to_jsonb(v_queue_id);
    END LOOP;

    RETURN jsonb_build_object('success', true, 'queue_ids', v_queue_ids, 'diff_count', v_diff_count);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
