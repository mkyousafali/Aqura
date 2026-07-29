-- ============================================================
-- EMAIL MODULE - RPC Functions
-- Migration: 20260729_email_module_rpcs.sql
-- ============================================================

-- ============ ACCOUNT RPCs ============

-- List email accounts (without secrets)
CREATE OR REPLACE FUNCTION public.get_email_accounts()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_agg(row_to_json(a)::jsonb ORDER BY a.account_name), '[]'::jsonb)
    FROM (
      SELECT ea.id, ea.account_name, ea.email_address, ea.from_name, ea.reply_to_address,
             ea.smtp_host, ea.smtp_port, ea.smtp_encryption, ea.smtp_username,
             ea.imap_host, ea.imap_port, ea.imap_encryption, ea.imap_username,
             ea.default_for_manual, ea.default_for_transactional, ea.default_for_otp,
             ea.default_for_broadcast, ea.default_for_incoming,
             ea.hourly_send_limit, ea.daily_send_limit, ea.maximum_recipients_per_message,
             ea.reserve_critical_per_hour, ea.queue_batch_size, ea.minimum_delay_seconds,
             ea.maximum_concurrent_sends, ea.maximum_retry_count,
             ea.sync_enabled, ea.send_enabled,
             ea.last_smtp_test_at, ea.last_smtp_test_status,
             ea.last_imap_test_at, ea.last_imap_test_status,
             ea.last_sync_at, ea.last_sync_status,
             ea.notes, ea.is_active, ea.created_at, ea.updated_at,
             ep.provider_name, ep.provider_code,
             -- Usage counters
             (SELECT coalesce(sum(uc.sent_count), 0) FROM public.email_usage_counters uc
              WHERE uc.email_account_id = ea.id AND uc.period_type = 'hourly'
              AND uc.period_start = date_trunc('hour', now())) as sent_this_hour,
             (SELECT coalesce(sum(uc.sent_count), 0) FROM public.email_usage_counters uc
              WHERE uc.email_account_id = ea.id AND uc.period_type = 'daily'
              AND uc.period_start = date_trunc('day', now())) as sent_today
      FROM public.email_accounts ea
      LEFT JOIN public.email_provider_presets ep ON ep.id = ea.provider_preset_id
      WHERE ea.is_active = true
    ) a
  );
END;
$$;

-- Get single email account
CREATE OR REPLACE FUNCTION public.get_email_account(p_account_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT row_to_json(a)::jsonb
    FROM (
      SELECT ea.*, ep.provider_name, ep.provider_code,
             CASE WHEN es.id IS NOT NULL THEN true ELSE false END as has_smtp_password,
             CASE WHEN es.encrypted_imap_password IS NOT NULL THEN true ELSE false END as has_imap_password
      FROM public.email_accounts ea
      LEFT JOIN public.email_provider_presets ep ON ep.id = ea.provider_preset_id
      LEFT JOIN public.email_account_secrets es ON es.email_account_id = ea.id
      WHERE ea.id = p_account_id
    ) a
  );
END;
$$;

-- Create email account
CREATE OR REPLACE FUNCTION public.create_email_account(
  p_account_name text,
  p_email_address text,
  p_provider_preset_id uuid DEFAULT NULL,
  p_from_name text DEFAULT NULL,
  p_reply_to_address text DEFAULT NULL,
  p_smtp_host text DEFAULT NULL,
  p_smtp_port integer DEFAULT 587,
  p_smtp_encryption text DEFAULT 'tls',
  p_smtp_username text DEFAULT NULL,
  p_imap_host text DEFAULT NULL,
  p_imap_port integer DEFAULT 993,
  p_imap_encryption text DEFAULT 'ssl',
  p_imap_username text DEFAULT NULL,
  p_hourly_send_limit integer DEFAULT 100,
  p_daily_send_limit integer DEFAULT 2000,
  p_sync_enabled boolean DEFAULT false,
  p_send_enabled boolean DEFAULT true,
  p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.email_accounts (
    account_name, email_address, provider_preset_id, from_name, reply_to_address,
    smtp_host, smtp_port, smtp_encryption, smtp_username,
    imap_host, imap_port, imap_encryption, imap_username,
    hourly_send_limit, daily_send_limit, sync_enabled, send_enabled, notes,
    created_by
  ) VALUES (
    p_account_name, p_email_address, p_provider_preset_id, p_from_name, p_reply_to_address,
    p_smtp_host, p_smtp_port, p_smtp_encryption, p_smtp_username,
    p_imap_host, p_imap_port, p_imap_encryption, p_imap_username,
    p_hourly_send_limit, p_daily_send_limit, p_sync_enabled, p_send_enabled, p_notes,
    auth.uid()
  ) RETURNING id INTO v_id;

  -- Create secrets row
  INSERT INTO public.email_account_secrets (email_account_id)
  VALUES (v_id);

  -- Log
  INSERT INTO public.email_logs (event_type, email_account_id, user_id, safe_message)
  VALUES ('account_created', v_id, auth.uid(), 'Email account created: ' || p_account_name);

  RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- Update email account
CREATE OR REPLACE FUNCTION public.update_email_account(
  p_id uuid,
  p_data jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_accounts SET
    account_name = coalesce(p_data->>'account_name', account_name),
    email_address = coalesce(p_data->>'email_address', email_address),
    provider_preset_id = CASE WHEN p_data ? 'provider_preset_id' THEN (p_data->>'provider_preset_id')::uuid ELSE provider_preset_id END,
    from_name = coalesce(p_data->>'from_name', from_name),
    reply_to_address = coalesce(p_data->>'reply_to_address', reply_to_address),
    smtp_host = coalesce(p_data->>'smtp_host', smtp_host),
    smtp_port = CASE WHEN p_data ? 'smtp_port' THEN (p_data->>'smtp_port')::integer ELSE smtp_port END,
    smtp_encryption = coalesce(p_data->>'smtp_encryption', smtp_encryption),
    smtp_username = coalesce(p_data->>'smtp_username', smtp_username),
    imap_host = coalesce(p_data->>'imap_host', imap_host),
    imap_port = CASE WHEN p_data ? 'imap_port' THEN (p_data->>'imap_port')::integer ELSE imap_port END,
    imap_encryption = coalesce(p_data->>'imap_encryption', imap_encryption),
    imap_username = coalesce(p_data->>'imap_username', imap_username),
    hourly_send_limit = CASE WHEN p_data ? 'hourly_send_limit' THEN (p_data->>'hourly_send_limit')::integer ELSE hourly_send_limit END,
    daily_send_limit = CASE WHEN p_data ? 'daily_send_limit' THEN (p_data->>'daily_send_limit')::integer ELSE daily_send_limit END,
    maximum_recipients_per_message = CASE WHEN p_data ? 'maximum_recipients_per_message' THEN (p_data->>'maximum_recipients_per_message')::integer ELSE maximum_recipients_per_message END,
    reserve_critical_per_hour = CASE WHEN p_data ? 'reserve_critical_per_hour' THEN (p_data->>'reserve_critical_per_hour')::integer ELSE reserve_critical_per_hour END,
    queue_batch_size = CASE WHEN p_data ? 'queue_batch_size' THEN (p_data->>'queue_batch_size')::integer ELSE queue_batch_size END,
    minimum_delay_seconds = CASE WHEN p_data ? 'minimum_delay_seconds' THEN (p_data->>'minimum_delay_seconds')::integer ELSE minimum_delay_seconds END,
    maximum_concurrent_sends = CASE WHEN p_data ? 'maximum_concurrent_sends' THEN (p_data->>'maximum_concurrent_sends')::integer ELSE maximum_concurrent_sends END,
    maximum_retry_count = CASE WHEN p_data ? 'maximum_retry_count' THEN (p_data->>'maximum_retry_count')::integer ELSE maximum_retry_count END,
    sync_enabled = CASE WHEN p_data ? 'sync_enabled' THEN (p_data->>'sync_enabled')::boolean ELSE sync_enabled END,
    send_enabled = CASE WHEN p_data ? 'send_enabled' THEN (p_data->>'send_enabled')::boolean ELSE send_enabled END,
    default_for_manual = CASE WHEN p_data ? 'default_for_manual' THEN (p_data->>'default_for_manual')::boolean ELSE default_for_manual END,
    default_for_transactional = CASE WHEN p_data ? 'default_for_transactional' THEN (p_data->>'default_for_transactional')::boolean ELSE default_for_transactional END,
    default_for_otp = CASE WHEN p_data ? 'default_for_otp' THEN (p_data->>'default_for_otp')::boolean ELSE default_for_otp END,
    default_for_broadcast = CASE WHEN p_data ? 'default_for_broadcast' THEN (p_data->>'default_for_broadcast')::boolean ELSE default_for_broadcast END,
    default_for_incoming = CASE WHEN p_data ? 'default_for_incoming' THEN (p_data->>'default_for_incoming')::boolean ELSE default_for_incoming END,
    notes = coalesce(p_data->>'notes', notes),
    updated_by = auth.uid()
  WHERE id = p_id;

  INSERT INTO public.email_logs (event_type, email_account_id, user_id, safe_message)
  VALUES ('account_updated', p_id, auth.uid(), 'Email account updated');

  RETURN jsonb_build_object('success', true);
END;
$$;

-- Delete/deactivate email account
CREATE OR REPLACE FUNCTION public.delete_email_account(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_accounts SET is_active = false, updated_by = auth.uid() WHERE id = p_id;
  
  INSERT INTO public.email_logs (event_type, email_account_id, user_id, safe_message)
  VALUES ('account_deactivated', p_id, auth.uid(), 'Email account deactivated');

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============ TEMPLATE RPCs ============

CREATE OR REPLACE FUNCTION public.get_email_templates()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.template_name), '[]'::jsonb)
    FROM public.email_templates t
    WHERE t.is_active = true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_email_template(p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.email_templates (
    template_name, template_code, category, subject_template,
    html_body_template, text_body_template, available_placeholders_json,
    default_signature_id, is_system_template, created_by
  ) VALUES (
    p_data->>'template_name', p_data->>'template_code', p_data->>'category',
    p_data->>'subject_template', p_data->>'html_body_template', p_data->>'text_body_template',
    coalesce(p_data->'available_placeholders_json', '[]'::jsonb),
    (p_data->>'default_signature_id')::uuid, coalesce((p_data->>'is_system_template')::boolean, false),
    auth.uid()
  ) RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_email_template(p_id uuid, p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  -- Save version before update
  INSERT INTO public.email_template_versions (email_template_id, version_number, subject_template, html_body_template, text_body_template, change_note, created_by)
  SELECT id, version, subject_template, html_body_template, text_body_template, 'Auto-saved before update', auth.uid()
  FROM public.email_templates WHERE id = p_id;

  UPDATE public.email_templates SET
    template_name = coalesce(p_data->>'template_name', template_name),
    template_code = coalesce(p_data->>'template_code', template_code),
    category = coalesce(p_data->>'category', category),
    subject_template = coalesce(p_data->>'subject_template', subject_template),
    html_body_template = coalesce(p_data->>'html_body_template', html_body_template),
    text_body_template = coalesce(p_data->>'text_body_template', text_body_template),
    available_placeholders_json = CASE WHEN p_data ? 'available_placeholders_json' THEN p_data->'available_placeholders_json' ELSE available_placeholders_json END,
    default_signature_id = CASE WHEN p_data ? 'default_signature_id' THEN (p_data->>'default_signature_id')::uuid ELSE default_signature_id END,
    version = version + 1,
    updated_by = auth.uid()
  WHERE id = p_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_email_template(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_templates SET is_active = false, updated_by = auth.uid() WHERE id = p_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============ SIGNATURE RPCs ============

CREATE OR REPLACE FUNCTION public.get_email_signatures()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_agg(row_to_json(s)::jsonb ORDER BY s.signature_name), '[]'::jsonb)
    FROM public.email_signatures s
    WHERE s.is_active = true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_email_signature(p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.email_signatures (signature_name, html_signature, text_signature, department, is_default, created_by)
  VALUES (p_data->>'signature_name', p_data->>'html_signature', p_data->>'text_signature', p_data->>'department', coalesce((p_data->>'is_default')::boolean, false), auth.uid())
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_email_signature(p_id uuid, p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_signatures SET
    signature_name = coalesce(p_data->>'signature_name', signature_name),
    html_signature = coalesce(p_data->>'html_signature', html_signature),
    text_signature = coalesce(p_data->>'text_signature', text_signature),
    department = coalesce(p_data->>'department', department),
    is_default = CASE WHEN p_data ? 'is_default' THEN (p_data->>'is_default')::boolean ELSE is_default END,
    updated_by = auth.uid()
  WHERE id = p_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_email_signature(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_signatures SET is_active = false, updated_by = auth.uid() WHERE id = p_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============ GROUP RPCs ============

CREATE OR REPLACE FUNCTION public.get_email_groups()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_agg(row_to_json(g)::jsonb ORDER BY g.group_name), '[]'::jsonb)
    FROM (
      SELECT eg.*,
        (SELECT count(*) FROM public.email_group_members egm WHERE egm.email_group_id = eg.id AND egm.is_active = true) as member_count
      FROM public.email_groups eg
      WHERE eg.is_active = true
    ) g
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_email_group(p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.email_groups (group_name, group_type, description, is_dynamic, dynamic_filter_json, created_by)
  VALUES (p_data->>'group_name', coalesce(p_data->>'group_type', 'static'), p_data->>'description', coalesce((p_data->>'is_dynamic')::boolean, false), p_data->'dynamic_filter_json', auth.uid())
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.add_email_group_member(p_group_id uuid, p_email_address text, p_display_name text DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.email_group_members (email_group_id, email_address, display_name)
  VALUES (p_group_id, p_email_address, p_display_name)
  ON CONFLICT (email_group_id, email_address) DO UPDATE SET is_active = true, display_name = coalesce(p_display_name, email_group_members.display_name)
  RETURNING id INTO v_id;
  RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.remove_email_group_member(p_group_id uuid, p_member_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_group_members SET is_active = false WHERE id = p_member_id AND email_group_id = p_group_id;
  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============ EMAIL CENTRE RPCs ============

CREATE OR REPLACE FUNCTION public.get_email_folders(p_account_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_agg(row_to_json(f)::jsonb ORDER BY f.display_order), '[]'::jsonb)
    FROM (
      SELECT ef.*,
        (SELECT count(*) FROM public.email_messages em WHERE em.folder_id = ef.id AND em.is_read = false AND em.is_deleted = false) as unread_count
      FROM public.email_folders ef
      WHERE ef.email_account_id = p_account_id AND ef.is_active = true
      ORDER BY CASE ef.folder_type
        WHEN 'inbox' THEN 1 WHEN 'sent' THEN 2 WHEN 'drafts' THEN 3
        WHEN 'starred' THEN 4 WHEN 'archive' THEN 5 WHEN 'spam' THEN 6
        WHEN 'trash' THEN 7 ELSE 8 END
    ) f
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_email_messages(
  p_account_id uuid,
  p_folder_id uuid DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_is_read boolean DEFAULT NULL,
  p_is_starred boolean DEFAULT NULL,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_offset integer;
  v_total integer;
BEGIN
  v_offset := (p_page - 1) * p_page_size;

  SELECT count(*) INTO v_total
  FROM public.email_messages em
  WHERE em.email_account_id = p_account_id
    AND em.is_deleted = false
    AND (p_folder_id IS NULL OR em.folder_id = p_folder_id)
    AND (p_is_read IS NULL OR em.is_read = p_is_read)
    AND (p_is_starred IS NULL OR em.is_starred = p_is_starred)
    AND (p_search IS NULL OR em.subject ILIKE '%' || p_search || '%' OR em.from_address ILIKE '%' || p_search || '%' OR em.body_preview ILIKE '%' || p_search || '%');

  RETURN jsonb_build_object(
    'total', v_total,
    'page', p_page,
    'page_size', p_page_size,
    'messages', (
      SELECT coalesce(jsonb_agg(row_to_json(m)::jsonb), '[]'::jsonb)
      FROM (
        SELECT em.id, em.folder_id, em.thread_id, em.direction, em.status, em.subject,
               em.from_name, em.from_address, em.body_preview, em.sent_at, em.received_at,
               em.is_read, em.is_starred, em.is_flagged, em.is_draft, em.priority,
               em.has_attachments, em.source_type,
               (SELECT count(*) FROM public.email_message_recipients r WHERE r.email_message_id = em.id) as recipient_count
        FROM public.email_messages em
        WHERE em.email_account_id = p_account_id
          AND em.is_deleted = false
          AND (p_folder_id IS NULL OR em.folder_id = p_folder_id)
          AND (p_is_read IS NULL OR em.is_read = p_is_read)
          AND (p_is_starred IS NULL OR em.is_starred = p_is_starred)
          AND (p_search IS NULL OR em.subject ILIKE '%' || p_search || '%' OR em.from_address ILIKE '%' || p_search || '%' OR em.body_preview ILIKE '%' || p_search || '%')
        ORDER BY coalesce(em.received_at, em.sent_at, em.created_at) DESC
        LIMIT p_page_size OFFSET v_offset
      ) m
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_email_message(p_message_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  -- Mark as read
  UPDATE public.email_messages SET is_read = true WHERE id = p_message_id AND is_read = false;

  RETURN (
    SELECT jsonb_build_object(
      'message', row_to_json(em)::jsonb,
      'recipients', (SELECT coalesce(jsonb_agg(row_to_json(r)::jsonb), '[]'::jsonb) FROM public.email_message_recipients r WHERE r.email_message_id = em.id),
      'attachments', (SELECT coalesce(jsonb_agg(row_to_json(a)::jsonb), '[]'::jsonb) FROM public.email_attachments a WHERE a.email_message_id = em.id)
    )
    FROM public.email_messages em
    WHERE em.id = p_message_id
  );
END;
$$;

-- Mark read/unread
CREATE OR REPLACE FUNCTION public.email_mark_read(p_message_ids uuid[], p_is_read boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_messages SET is_read = p_is_read WHERE id = ANY(p_message_ids);
  RETURN jsonb_build_object('success', true, 'count', array_length(p_message_ids, 1));
END;
$$;

-- Star/unstar
CREATE OR REPLACE FUNCTION public.email_toggle_star(p_message_ids uuid[], p_is_starred boolean DEFAULT true)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_messages SET is_starred = p_is_starred WHERE id = ANY(p_message_ids);
  RETURN jsonb_build_object('success', true);
END;
$$;

-- Archive
CREATE OR REPLACE FUNCTION public.email_archive(p_message_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_messages SET is_archived = true WHERE id = ANY(p_message_ids);
  RETURN jsonb_build_object('success', true);
END;
$$;

-- Soft delete
CREATE OR REPLACE FUNCTION public.email_soft_delete(p_message_ids uuid[])
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_messages SET is_deleted = true WHERE id = ANY(p_message_ids);
  RETURN jsonb_build_object('success', true);
END;
$$;

-- Save draft
CREATE OR REPLACE FUNCTION public.save_email_draft(p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_id uuid;
  v_account_id uuid;
  v_folder_id uuid;
BEGIN
  v_account_id := (p_data->>'email_account_id')::uuid;
  
  -- Get drafts folder
  SELECT id INTO v_folder_id FROM public.email_folders
  WHERE email_account_id = v_account_id AND folder_type = 'drafts' LIMIT 1;

  IF p_data ? 'id' AND (p_data->>'id') IS NOT NULL THEN
    -- Update existing draft
    v_id := (p_data->>'id')::uuid;
    UPDATE public.email_messages SET
      subject = p_data->>'subject',
      html_body = p_data->>'html_body',
      text_body = p_data->>'text_body',
      body_preview = left(p_data->>'text_body', 200)
    WHERE id = v_id AND is_draft = true;
  ELSE
    -- Create new draft
    INSERT INTO public.email_messages (
      email_account_id, folder_id, direction, status, subject,
      from_name, from_address, html_body, text_body, body_preview,
      is_draft, source_type, created_by_user_id
    ) VALUES (
      v_account_id, v_folder_id, 'outbound', 'draft', p_data->>'subject',
      p_data->>'from_name', p_data->>'from_address',
      p_data->>'html_body', p_data->>'text_body', left(p_data->>'text_body', 200),
      true, 'manual', auth.uid()
    ) RETURNING id INTO v_id;
  END IF;

  -- Upsert recipients
  DELETE FROM public.email_message_recipients WHERE email_message_id = v_id;
  IF p_data ? 'recipients' THEN
    INSERT INTO public.email_message_recipients (email_message_id, recipient_type, email_address, display_name)
    SELECT v_id, r->>'type', r->>'email', r->>'name'
    FROM jsonb_array_elements(p_data->'recipients') r;
  END IF;

  RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- Queue email for sending
CREATE OR REPLACE FUNCTION public.queue_email_send(p_message_id uuid, p_queue_type text DEFAULT 'normal', p_priority integer DEFAULT 5)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_account_id uuid;
  v_queue_id uuid;
  v_idempotency_key text;
BEGIN
  -- Get account
  SELECT email_account_id INTO v_account_id FROM public.email_messages WHERE id = p_message_id;
  
  IF v_account_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Message not found');
  END IF;

  -- Generate idempotency key
  v_idempotency_key := 'send-' || p_message_id::text || '-' || extract(epoch from now())::text;

  -- Update message status
  UPDATE public.email_messages SET status = 'queued', is_draft = false WHERE id = p_message_id;

  -- Create queue item
  INSERT INTO public.email_queue (queue_type, priority, email_account_id, email_message_id, status, idempotency_key)
  VALUES (p_queue_type, p_priority, v_account_id, p_message_id, 'waiting', v_idempotency_key)
  RETURNING id INTO v_queue_id;

  INSERT INTO public.email_logs (event_type, email_account_id, email_message_id, queue_item_id, user_id, safe_message)
  VALUES ('message_queued', v_account_id, p_message_id, v_queue_id, auth.uid(), 'Email queued for sending');

  RETURN jsonb_build_object('success', true, 'queue_id', v_queue_id);
END;
$$;

-- ============ CAMPAIGN RPCs ============

CREATE OR REPLACE FUNCTION public.get_email_campaigns()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_agg(row_to_json(c)::jsonb ORDER BY c.created_at DESC), '[]'::jsonb)
    FROM public.email_campaigns c
    WHERE c.is_active = true
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_email_campaign(p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_id uuid;
BEGIN
  INSERT INTO public.email_campaigns (
    campaign_name, email_account_id, email_template_id,
    subject_override, html_body_override, text_body_override,
    batch_size_override, delay_override_seconds, created_by_user_id
  ) VALUES (
    p_data->>'campaign_name', (p_data->>'email_account_id')::uuid, (p_data->>'email_template_id')::uuid,
    p_data->>'subject_override', p_data->>'html_body_override', p_data->>'text_body_override',
    (p_data->>'batch_size_override')::integer, (p_data->>'delay_override_seconds')::integer, auth.uid()
  ) RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'id', v_id);
END;
$$;

-- ============ QUEUE RPCs ============

CREATE OR REPLACE FUNCTION public.get_email_queue(
  p_status text DEFAULT NULL,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_offset integer;
BEGIN
  v_offset := (p_page - 1) * p_page_size;
  RETURN jsonb_build_object(
    'summary', (
      SELECT jsonb_build_object(
        'waiting', count(*) FILTER (WHERE status = 'waiting'),
        'processing', count(*) FILTER (WHERE status = 'processing'),
        'sent', count(*) FILTER (WHERE status = 'sent'),
        'temporary_failed', count(*) FILTER (WHERE status = 'temporary_failed'),
        'permanent_failed', count(*) FILTER (WHERE status = 'permanent_failed'),
        'paused', count(*) FILTER (WHERE status = 'paused'),
        'cancelled', count(*) FILTER (WHERE status = 'cancelled')
      ) FROM public.email_queue WHERE created_at > now() - interval '24 hours'
    ),
    'items', (
      SELECT coalesce(jsonb_agg(row_to_json(q)::jsonb), '[]'::jsonb)
      FROM (
        SELECT eq.id, eq.queue_type, eq.priority, eq.status, eq.attempt_count, eq.maximum_attempts,
               eq.scheduled_at, eq.next_retry_at, eq.last_error_message, eq.created_at,
               em.subject, em.from_address,
               ea.account_name
        FROM public.email_queue eq
        LEFT JOIN public.email_messages em ON em.id = eq.email_message_id
        LEFT JOIN public.email_accounts ea ON ea.id = eq.email_account_id
        WHERE (p_status IS NULL OR eq.status = p_status)
        ORDER BY eq.created_at DESC
        LIMIT p_page_size OFFSET v_offset
      ) q
    )
  );
END;
$$;

-- ============ DASHBOARD RPCs ============

CREATE OR REPLACE FUNCTION public.get_email_dashboard()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN jsonb_build_object(
    'sent_today', (SELECT count(*) FROM public.email_messages WHERE direction = 'outbound' AND status = 'sent' AND sent_at >= date_trunc('day', now())),
    'received_today', (SELECT count(*) FROM public.email_messages WHERE direction = 'inbound' AND received_at >= date_trunc('day', now())),
    'failed_today', (SELECT count(*) FROM public.email_queue WHERE status IN ('temporary_failed', 'permanent_failed') AND created_at >= date_trunc('day', now())),
    'pending_queue', (SELECT count(*) FROM public.email_queue WHERE status IN ('waiting', 'processing')),
    'scheduled', (SELECT count(*) FROM public.email_messages WHERE scheduled_at IS NOT NULL AND status = 'queued' AND scheduled_at > now()),
    'unread', (SELECT count(*) FROM public.email_messages WHERE is_read = false AND is_deleted = false AND direction = 'inbound'),
    'active_campaigns', (SELECT count(*) FROM public.email_campaigns WHERE status IN ('running', 'queued', 'scheduled')),
    'accounts', (SELECT coalesce(jsonb_agg(jsonb_build_object(
      'id', ea.id, 'name', ea.account_name, 'email', ea.email_address,
      'smtp_status', ea.last_smtp_test_status, 'imap_status', ea.last_imap_test_status,
      'last_sync', ea.last_sync_at, 'send_enabled', ea.send_enabled, 'sync_enabled', ea.sync_enabled
    )), '[]'::jsonb) FROM public.email_accounts ea WHERE ea.is_active = true),
    'recent_activity', (
      SELECT coalesce(jsonb_agg(row_to_json(l)::jsonb), '[]'::jsonb)
      FROM (SELECT event_type, safe_message, created_at FROM public.email_logs ORDER BY created_at DESC LIMIT 10) l
    )
  );
END;
$$;

-- ============ SETTINGS RPCs ============

CREATE OR REPLACE FUNCTION public.get_email_settings()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_object_agg(setting_key, setting_value_json), '{}'::jsonb)
    FROM public.email_settings
    WHERE is_sensitive = false
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.update_email_setting(p_key text, p_value jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_settings SET setting_value_json = p_value WHERE setting_key = p_key AND is_sensitive = false;
  INSERT INTO public.email_logs (event_type, user_id, safe_message)
  VALUES ('setting_changed', auth.uid(), 'Setting updated: ' || p_key);
  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============ AI SETTINGS RPCs ============

CREATE OR REPLACE FUNCTION public.get_email_ai_settings()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_agg(row_to_json(s)::jsonb ORDER BY s.feature_name), '[]'::jsonb)
    FROM public.email_ai_settings s
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.update_email_ai_setting(p_feature_name text, p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.email_ai_settings SET
    is_enabled = CASE WHEN p_data ? 'is_enabled' THEN (p_data->>'is_enabled')::boolean ELSE is_enabled END,
    approval_required = CASE WHEN p_data ? 'approval_required' THEN (p_data->>'approval_required')::boolean ELSE approval_required END,
    provider_reference = coalesce(p_data->>'provider_reference', provider_reference),
    model_reference = coalesce(p_data->>'model_reference', model_reference),
    prompt_template = coalesce(p_data->>'prompt_template', prompt_template),
    auto_send_allowed = CASE WHEN p_data ? 'auto_send_allowed' THEN (p_data->>'auto_send_allowed')::boolean ELSE auto_send_allowed END,
    maximum_tokens = CASE WHEN p_data ? 'maximum_tokens' THEN (p_data->>'maximum_tokens')::integer ELSE maximum_tokens END
  WHERE feature_name = p_feature_name;
  RETURN jsonb_build_object('success', true);
END;
$$;

-- ============ REPORT RPCs ============

CREATE OR REPLACE FUNCTION public.get_email_logs_report(
  p_event_type text DEFAULT NULL,
  p_account_id uuid DEFAULT NULL,
  p_date_from timestamptz DEFAULT NULL,
  p_date_to timestamptz DEFAULT NULL,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 50
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_offset integer;
BEGIN
  v_offset := (p_page - 1) * p_page_size;
  RETURN jsonb_build_object(
    'total', (
      SELECT count(*) FROM public.email_logs
      WHERE (p_event_type IS NULL OR event_type = p_event_type)
        AND (p_account_id IS NULL OR email_account_id = p_account_id)
        AND (p_date_from IS NULL OR created_at >= p_date_from)
        AND (p_date_to IS NULL OR created_at <= p_date_to)
    ),
    'logs', (
      SELECT coalesce(jsonb_agg(row_to_json(l)::jsonb), '[]'::jsonb)
      FROM (
        SELECT el.*, ea.account_name
        FROM public.email_logs el
        LEFT JOIN public.email_accounts ea ON ea.id = el.email_account_id
        WHERE (p_event_type IS NULL OR el.event_type = p_event_type)
          AND (p_account_id IS NULL OR el.email_account_id = p_account_id)
          AND (p_date_from IS NULL OR el.created_at >= p_date_from)
          AND (p_date_to IS NULL OR el.created_at <= p_date_to)
        ORDER BY el.created_at DESC
        LIMIT p_page_size OFFSET v_offset
      ) l
    )
  );
END;
$$;

-- Provider presets
CREATE OR REPLACE FUNCTION public.get_email_provider_presets()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT coalesce(jsonb_agg(row_to_json(p)::jsonb ORDER BY p.provider_name), '[]'::jsonb)
    FROM public.email_provider_presets p
    WHERE p.is_active = true
  );
END;
$$;
