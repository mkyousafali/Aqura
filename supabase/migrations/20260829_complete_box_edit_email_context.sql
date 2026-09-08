-- Enriches the Complete Box edit-approval emails (OTP request, and the
-- save/cancel notification) with bilingual context: branch name, branch
-- location, cashier name, and the name of the user who started the box
-- closing — all derived server-side from box_operations/branches/
-- hr_employee_master rather than trusted from the frontend, since this is
-- exactly the kind of accountability data that must not be spoofable by
-- whatever string the client happens to pass in. Names come from
-- hr_employee_master.name_en / name_ar (joined via user_id), per the user's
-- explicit instruction.

CREATE FUNCTION public.get_complete_box_edit_context(p_box_operation_id uuid)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path TO 'public'
AS $$
DECLARE
    v_box_number smallint;
    v_cashier_user_id uuid;
    v_closer_user_id uuid;
    v_branch_name_en text;
    v_branch_name_ar text;
    v_branch_location_en text;
    v_branch_location_ar text;
    v_cashier_name_en text;
    v_cashier_name_ar text;
    v_closer_name_en text;
    v_closer_name_ar text;
BEGIN
    SELECT bo.box_number, bo.user_id, bo.completed_by_user_id,
           br.name_en, br.name_ar, br.location_en, br.location_ar
    INTO v_box_number, v_cashier_user_id, v_closer_user_id,
         v_branch_name_en, v_branch_name_ar, v_branch_location_en, v_branch_location_ar
    FROM public.box_operations bo
    LEFT JOIN public.branches br ON br.id = bo.branch_id
    WHERE bo.id = p_box_operation_id;

    IF v_cashier_user_id IS NOT NULL THEN
        SELECT name_en, name_ar INTO v_cashier_name_en, v_cashier_name_ar
        FROM public.hr_employee_master WHERE user_id = v_cashier_user_id;
    END IF;

    IF v_closer_user_id IS NOT NULL THEN
        SELECT name_en, name_ar INTO v_closer_name_en, v_closer_name_ar
        FROM public.hr_employee_master WHERE user_id = v_closer_user_id;
    END IF;

    RETURN jsonb_build_object(
        'box_number', v_box_number,
        'branch_name_en', v_branch_name_en, 'branch_name_ar', v_branch_name_ar,
        'branch_location_en', v_branch_location_en, 'branch_location_ar', v_branch_location_ar,
        'cashier_name_en', v_cashier_name_en, 'cashier_name_ar', v_cashier_name_ar,
        'closer_name_en', v_closer_name_en, 'closer_name_ar', v_closer_name_ar
    );
END;
$$;

COMMENT ON FUNCTION public.get_complete_box_edit_context(uuid) IS
    'Bilingual identifying context for a box_operations row — branch, branch location, cashier, and the user who started closing it — for the Complete Box edit-approval emails.';

-- Bilingual English/Arabic details table, shared by the OTP and the
-- save/cancel notification emails.
CREATE FUNCTION public.build_complete_box_context_html(p_context jsonb, p_pos_number text DEFAULT NULL)
RETURNS text
LANGUAGE sql STABLE
AS $$
    SELECT
        '<table style="width:100%;border-collapse:collapse;font-size:13px;margin:0 0 20px;">'
        || '<tr><td style="padding:4px 8px;color:#6b7280;font-weight:600;white-space:nowrap;">Box Number / رقم الصندوق</td>'
        || '<td style="padding:4px 8px;color:#374151;">' || COALESCE(p_context->>'box_number', '—') || '</td></tr>'
        || '<tr><td style="padding:4px 8px;color:#6b7280;font-weight:600;white-space:nowrap;">POS Number / رقم نقطة البيع</td>'
        || '<td style="padding:4px 8px;color:#374151;">' || COALESCE(p_pos_number, '—') || '</td></tr>'
        || '<tr><td style="padding:4px 8px;color:#6b7280;font-weight:600;white-space:nowrap;">Branch / الفرع</td>'
        || '<td style="padding:4px 8px;color:#374151;">' || COALESCE(p_context->>'branch_name_en', '—') || ' / ' || COALESCE(p_context->>'branch_name_ar', '—') || '</td></tr>'
        || '<tr><td style="padding:4px 8px;color:#6b7280;font-weight:600;white-space:nowrap;">Location / الموقع</td>'
        || '<td style="padding:4px 8px;color:#374151;">' || COALESCE(p_context->>'branch_location_en', '—') || ' / ' || COALESCE(p_context->>'branch_location_ar', '—') || '</td></tr>'
        || '<tr><td style="padding:4px 8px;color:#6b7280;font-weight:600;white-space:nowrap;">Cashier / الكاشير</td>'
        || '<td style="padding:4px 8px;color:#374151;">' || COALESCE(p_context->>'cashier_name_en', '—') || ' / ' || COALESCE(p_context->>'cashier_name_ar', '—') || '</td></tr>'
        || '<tr><td style="padding:4px 8px;color:#6b7280;font-weight:600;white-space:nowrap;">Started By / بدأ الإغلاق بواسطة</td>'
        || '<td style="padding:4px 8px;color:#374151;">' || COALESCE(p_context->>'closer_name_en', '—') || ' / ' || COALESCE(p_context->>'closer_name_ar', '—') || '</td></tr>'
        || '</table>';
$$;

-- ============================================================
-- send_complete_box_edit_otp — now derives all context server-side.
-- Signature change: p_box_number/p_branch_name replaced by p_pos_number
-- (box number, branch name, and location are looked up, not trusted from
-- the caller). A changed parameter count/type creates a new overload rather
-- than replacing the function, so the old 4-parameter signature is dropped
-- explicitly first.
-- ============================================================
DROP FUNCTION IF EXISTS public.send_complete_box_edit_otp(uuid, uuid, text, text);

CREATE OR REPLACE FUNCTION public.send_complete_box_edit_otp(
    p_box_operation_id uuid,
    p_requested_by uuid,
    p_pos_number text DEFAULT NULL
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
    v_context jsonb;
    v_context_html text;
BEGIN
    v_context := public.get_complete_box_edit_context(p_box_operation_id);
    v_context_html := public.build_complete_box_context_html(v_context, p_pos_number);

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

        v_html := '<div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto;padding:30px;">'
            || '<div style="text-align:center;margin-bottom:24px;"><h2 style="color:#059669;margin:0;">Aqura</h2>'
            || '<p style="color:#6b7280;font-size:14px;">Complete Box Edit Approval / موافقة تعديل صندوق الإغلاق</p></div>'
            || '<p style="color:#374151;font-size:14px;">A request was made to edit a closing box record.<br>'
            || 'تم تقديم طلب لتعديل سجل إغلاق صندوق.</p>'
            || v_context_html
            || '<div style="background:#f0fdf4;border:2px solid #059669;border-radius:12px;padding:24px;text-align:center;margin-bottom:20px;">'
            || '<p style="color:#374151;font-size:14px;margin:0 0 8px;">Approval code / رمز الموافقة:</p>'
            || '<div style="font-size:36px;font-weight:700;letter-spacing:8px;color:#059669;margin:12px 0;">' || v_otp || '</div>'
            || '<p style="color:#6b7280;font-size:12px;margin:8px 0 0;">Expires in 5 minutes / تنتهي الصلاحية خلال 5 دقائق</p></div>'
            || '<p style="color:#9ca3af;font-size:11px;text-align:center;">Only share this code with the person who should be allowed to make this edit.<br>'
            || 'لا تشارك هذا الرمز إلا مع الشخص المسموح له بإجراء هذا التعديل.</p>'
            || '</div>';

        INSERT INTO public.email_messages (
            email_account_id, direction, status, subject, text_body, html_body,
            priority, from_address, from_name
        ) VALUES (
            v_account_id, 'outgoing', 'queued',
            'Aqura - Box Edit Approval Code (Box #' || COALESCE(v_context->>'box_number', '?') || ')',
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
-- resolve_complete_box_edit — same bilingual context in the save/cancel
-- notification. Signature change: p_box_number/p_branch_name replaced by
-- p_pos_number — old signature dropped first for the same reason as above.
-- ============================================================
DROP FUNCTION IF EXISTS public.resolve_complete_box_edit(uuid, text, jsonb, text, text);

CREATE OR REPLACE FUNCTION public.resolve_complete_box_edit(
    p_history_id uuid,
    p_status text,
    p_after_data jsonb DEFAULT NULL,
    p_pos_number text DEFAULT NULL
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
    v_context jsonb;
    v_context_html text;
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

    v_context := public.get_complete_box_edit_context(v_history.box_operation_id);
    v_context_html := public.build_complete_box_context_html(v_context, p_pos_number);

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
        v_subject := 'Aqura - Box Edit Saved (Box #' || COALESCE(v_context->>'box_number', '?') || ')';
        v_html := '<div style="font-family:Arial,sans-serif;max-width:560px;margin:0 auto;padding:30px;">'
            || '<div style="text-align:center;margin-bottom:20px;"><h2 style="color:#059669;margin:0;">Aqura</h2>'
            || '<p style="color:#6b7280;font-size:14px;">Box Edit Saved / تم حفظ تعديل الصندوق</p></div>'
            || v_context_html
            || CASE WHEN v_diff_count = 0
                THEN '<p style="color:#6b7280;font-size:13px;">The edit was saved, but no field values actually changed. / تم الحفظ دون أي تغيير فعلي في القيم.</p>'
                ELSE '<table style="width:100%;border-collapse:collapse;font-size:13px;">'
                    || '<tr style="background:#f9fafb;"><th style="padding:6px 10px;text-align:left;">Field</th><th style="padding:6px 10px;text-align:left;">Before</th><th style="padding:6px 10px;text-align:left;">After</th></tr>'
                    || v_diff_rows || '</table>'
            END
            || '</div>';
    ELSE
        v_subject := 'Aqura - Box Edit Cancelled (Box #' || COALESCE(v_context->>'box_number', '?') || ')';
        v_html := '<div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto;padding:30px;">'
            || '<div style="text-align:center;margin-bottom:20px;"><h2 style="color:#6b7280;margin:0;">Aqura</h2>'
            || '<p style="color:#6b7280;font-size:14px;">Box Edit Cancelled / تم إلغاء تعديل الصندوق</p></div>'
            || v_context_html
            || '<p style="color:#374151;font-size:14px;">No changes were made in that session — the edit request was cancelled (or abandoned) before anything was saved.<br>'
            || 'لم يتم إجراء أي تغييرات في تلك الجلسة — تم إلغاء طلب التعديل (أو تركه) قبل حفظ أي شيء.</p>'
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
