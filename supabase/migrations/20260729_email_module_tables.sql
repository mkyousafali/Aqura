-- ============================================================
-- EMAIL MODULE - Database Tables, Indexes, RLS, Triggers
-- Migration: 20260729_email_module_tables.sql
-- ============================================================

-- ============ MAIN SECTION & SUBSECTIONS ============

-- Insert Email main section
INSERT INTO public.button_main_sections (section_name_en, section_name_ar, section_code, display_order, is_active)
VALUES ('Email', 'البريد الإلكتروني', 'EMAIL', 12, true)
ON CONFLICT DO NOTHING;

-- Get the section ID for references
DO $$
DECLARE
  v_section_id bigint;
  v_sub_dashboard_id bigint;
  v_sub_manage_id bigint;
  v_sub_operations_id bigint;
  v_sub_reports_id bigint;
BEGIN
  SELECT id INTO v_section_id FROM public.button_main_sections WHERE section_code = 'EMAIL';

  -- Insert subsections
  INSERT INTO public.button_sub_sections (main_section_id, subsection_name_en, subsection_name_ar, subsection_code, display_order, is_active)
  VALUES (v_section_id, 'Dashboard', 'لوحة القيادة', 'DASHBOARD', 1, true)
  ON CONFLICT DO NOTHING;

  INSERT INTO public.button_sub_sections (main_section_id, subsection_name_en, subsection_name_ar, subsection_code, display_order, is_active)
  VALUES (v_section_id, 'Management', 'الإدارة', 'MANAGE', 2, true)
  ON CONFLICT DO NOTHING;

  INSERT INTO public.button_sub_sections (main_section_id, subsection_name_en, subsection_name_ar, subsection_code, display_order, is_active)
  VALUES (v_section_id, 'Operations', 'العمليات', 'OPERATIONS', 3, true)
  ON CONFLICT DO NOTHING;

  INSERT INTO public.button_sub_sections (main_section_id, subsection_name_en, subsection_name_ar, subsection_code, display_order, is_active)
  VALUES (v_section_id, 'Reports', 'التقارير', 'REPORTS', 4, true)
  ON CONFLICT DO NOTHING;

  -- Get subsection IDs
  SELECT id INTO v_sub_dashboard_id FROM public.button_sub_sections WHERE main_section_id = v_section_id AND subsection_code = 'DASHBOARD';
  SELECT id INTO v_sub_manage_id FROM public.button_sub_sections WHERE main_section_id = v_section_id AND subsection_code = 'MANAGE';
  SELECT id INTO v_sub_operations_id FROM public.button_sub_sections WHERE main_section_id = v_section_id AND subsection_code = 'OPERATIONS';
  SELECT id INTO v_sub_reports_id FROM public.button_sub_sections WHERE main_section_id = v_section_id AND subsection_code = 'REPORTS';

  -- Insert sidebar buttons
  -- Dashboard
  INSERT INTO public.sidebar_buttons (main_section_id, subsection_id, button_name_en, button_name_ar, button_code, icon, display_order, is_active)
  VALUES (v_section_id, v_sub_dashboard_id, 'Email Dashboard', 'لوحة البريد', 'EMAIL_DASHBOARD', '📊', 1, true)
  ON CONFLICT DO NOTHING;

  -- Management
  INSERT INTO public.sidebar_buttons (main_section_id, subsection_id, button_name_en, button_name_ar, button_code, icon, display_order, is_active)
  VALUES
    (v_section_id, v_sub_manage_id, 'Email Accounts', 'حسابات البريد', 'EMAIL_ACCOUNTS', '📱', 1, true),
    (v_section_id, v_sub_manage_id, 'Email Templates', 'قوالب البريد', 'EMAIL_TEMPLATES', '📝', 2, true),
    (v_section_id, v_sub_manage_id, 'Email Signatures', 'توقيعات البريد', 'EMAIL_SIGNATURES', '✍️', 3, true),
    (v_section_id, v_sub_manage_id, 'Email Groups', 'مجموعات البريد', 'EMAIL_GROUPS', '👥', 4, true),
    (v_section_id, v_sub_manage_id, 'Email Settings', 'إعدادات البريد', 'EMAIL_SETTINGS', '⚙️', 5, true),
    (v_section_id, v_sub_manage_id, 'AI Email Settings', 'إعدادات الذكاء', 'EMAIL_AI_SETTINGS', '🤖', 6, true)
  ON CONFLICT DO NOTHING;

  -- Operations
  INSERT INTO public.sidebar_buttons (main_section_id, subsection_id, button_name_en, button_name_ar, button_code, icon, display_order, is_active)
  VALUES
    (v_section_id, v_sub_operations_id, 'Email Centre', 'مركز البريد', 'EMAIL_CENTRE', '📬', 1, true),
    (v_section_id, v_sub_operations_id, 'Compose Email', 'إنشاء بريد', 'EMAIL_COMPOSE', '✉️', 2, true),
    (v_section_id, v_sub_operations_id, 'Broadcast Email', 'بث البريد', 'EMAIL_BROADCAST', '📣', 3, true),
    (v_section_id, v_sub_operations_id, 'Email Queue', 'قائمة الانتظار', 'EMAIL_QUEUE', '📋', 4, true),
    (v_section_id, v_sub_operations_id, 'Scheduled Emails', 'البريد المجدول', 'EMAIL_SCHEDULED', '🕐', 5, true)
  ON CONFLICT DO NOTHING;

  -- Reports
  INSERT INTO public.sidebar_buttons (main_section_id, subsection_id, button_name_en, button_name_ar, button_code, icon, display_order, is_active)
  VALUES
    (v_section_id, v_sub_reports_id, 'Email Logs', 'سجلات البريد', 'EMAIL_LOGS', '📄', 1, true),
    (v_section_id, v_sub_reports_id, 'Delivery Reports', 'تقارير التسليم', 'EMAIL_DELIVERY_REPORTS', '✅', 2, true),
    (v_section_id, v_sub_reports_id, 'Campaign Reports', 'تقارير الحملات', 'EMAIL_CAMPAIGN_REPORTS', '📈', 3, true),
    (v_section_id, v_sub_reports_id, 'Failed Emails', 'البريد الفاشل', 'EMAIL_FAILED', '❌', 4, true)
  ON CONFLICT DO NOTHING;
END $$;


-- ============ EMAIL TABLES ============

-- 1. email_provider_presets
CREATE TABLE IF NOT EXISTS public.email_provider_presets (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    provider_code varchar(50) NOT NULL UNIQUE,
    provider_name varchar(255) NOT NULL,
    smtp_host varchar(255),
    smtp_port integer DEFAULT 587,
    smtp_encryption varchar(20) DEFAULT 'tls',
    imap_host varchar(255),
    imap_port integer DEFAULT 993,
    imap_encryption varchar(20) DEFAULT 'ssl',
    supports_delivery_webhooks boolean DEFAULT false,
    supports_open_tracking boolean DEFAULT false,
    supports_click_tracking boolean DEFAULT false,
    supports_api_send boolean DEFAULT false,
    documentation_note text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 2. email_accounts
CREATE TABLE IF NOT EXISTS public.email_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    account_name varchar(255) NOT NULL,
    provider_preset_id uuid REFERENCES public.email_provider_presets(id),
    email_address varchar(255) NOT NULL,
    from_name varchar(255),
    reply_to_address varchar(255),
    smtp_host varchar(255),
    smtp_port integer DEFAULT 587,
    smtp_encryption varchar(20) DEFAULT 'tls',
    smtp_username varchar(255),
    imap_host varchar(255),
    imap_port integer DEFAULT 993,
    imap_encryption varchar(20) DEFAULT 'ssl',
    imap_username varchar(255),
    default_for_manual boolean DEFAULT false,
    default_for_transactional boolean DEFAULT false,
    default_for_otp boolean DEFAULT false,
    default_for_broadcast boolean DEFAULT false,
    default_for_incoming boolean DEFAULT false,
    hourly_send_limit integer DEFAULT 100,
    daily_send_limit integer DEFAULT 2000,
    maximum_recipients_per_message integer DEFAULT 50,
    reserve_critical_per_hour integer DEFAULT 10,
    queue_batch_size integer DEFAULT 10,
    minimum_delay_seconds integer DEFAULT 2,
    maximum_concurrent_sends integer DEFAULT 3,
    maximum_retry_count integer DEFAULT 3,
    sync_enabled boolean DEFAULT false,
    send_enabled boolean DEFAULT true,
    last_smtp_test_at timestamptz,
    last_smtp_test_status varchar(50),
    last_imap_test_at timestamptz,
    last_imap_test_status varchar(50),
    last_sync_at timestamptz,
    last_sync_status varchar(50),
    notes text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    created_by uuid,
    updated_at timestamptz DEFAULT now(),
    updated_by uuid
);

-- 3. email_account_secrets (server-only)
CREATE TABLE IF NOT EXISTS public.email_account_secrets (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_account_id uuid NOT NULL REFERENCES public.email_accounts(id) ON DELETE CASCADE,
    encrypted_smtp_password text,
    encrypted_imap_password text,
    encrypted_api_key text,
    encrypted_webhook_secret text,
    encryption_version integer DEFAULT 1,
    key_reference varchar(100),
    rotated_at timestamptz,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 4. email_folders
CREATE TABLE IF NOT EXISTS public.email_folders (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_account_id uuid NOT NULL REFERENCES public.email_accounts(id) ON DELETE CASCADE,
    remote_folder_name varchar(255) NOT NULL,
    display_name varchar(255),
    folder_type varchar(50) DEFAULT 'custom',
    delimiter varchar(5),
    uid_validity bigint,
    last_synced_uid bigint DEFAULT 0,
    last_sync_at timestamptz,
    is_selectable boolean DEFAULT true,
    is_subscribed boolean DEFAULT true,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 5. email_threads
CREATE TABLE IF NOT EXISTS public.email_threads (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_account_id uuid NOT NULL REFERENCES public.email_accounts(id) ON DELETE CASCADE,
    normalised_subject text,
    latest_message_at timestamptz,
    message_count integer DEFAULT 0,
    unread_count integer DEFAULT 0,
    participants_json jsonb DEFAULT '[]'::jsonb,
    linked_entity_type varchar(50),
    linked_entity_id uuid,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 6. email_messages
CREATE TABLE IF NOT EXISTS public.email_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_account_id uuid NOT NULL REFERENCES public.email_accounts(id) ON DELETE CASCADE,
    folder_id uuid REFERENCES public.email_folders(id),
    thread_id uuid REFERENCES public.email_threads(id),
    remote_uid bigint,
    uid_validity bigint,
    message_id_header text,
    in_reply_to_header text,
    references_header text,
    direction varchar(10) NOT NULL DEFAULT 'inbound', -- inbound, outbound
    status varchar(30) DEFAULT 'received', -- received, draft, queued, sending, sent, failed
    subject text,
    from_name varchar(255),
    from_address varchar(255),
    reply_to_address varchar(255),
    html_body text,
    text_body text,
    body_preview varchar(500),
    sent_at timestamptz,
    received_at timestamptz,
    scheduled_at timestamptz,
    is_read boolean DEFAULT false,
    is_starred boolean DEFAULT false,
    is_flagged boolean DEFAULT false,
    is_draft boolean DEFAULT false,
    is_archived boolean DEFAULT false,
    is_deleted boolean DEFAULT false,
    priority varchar(20) DEFAULT 'normal',
    importance varchar(20) DEFAULT 'normal',
    has_attachments boolean DEFAULT false,
    spam_score numeric(5,2),
    linked_entity_type varchar(50),
    linked_entity_id uuid,
    source_type varchar(50), -- manual, broadcast, transactional, otp, system
    source_reference varchar(255),
    created_by_user_id uuid,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 7. email_message_recipients
CREATE TABLE IF NOT EXISTS public.email_message_recipients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_message_id uuid NOT NULL REFERENCES public.email_messages(id) ON DELETE CASCADE,
    recipient_type varchar(5) NOT NULL DEFAULT 'to', -- to, cc, bcc
    display_name varchar(255),
    email_address varchar(255) NOT NULL,
    delivery_status varchar(30) DEFAULT 'pending',
    delivered_at timestamptz,
    opened_at timestamptz,
    clicked_at timestamptz,
    bounced_at timestamptz,
    complained_at timestamptz,
    failure_code varchar(50),
    failure_message text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 8. email_attachments
CREATE TABLE IF NOT EXISTS public.email_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_message_id uuid NOT NULL REFERENCES public.email_messages(id) ON DELETE CASCADE,
    file_name varchar(500) NOT NULL,
    original_file_name varchar(500),
    content_type varchar(255),
    file_size bigint DEFAULT 0,
    storage_bucket varchar(100),
    storage_path text,
    content_id varchar(255),
    is_inline boolean DEFAULT false,
    checksum varchar(128),
    scan_status varchar(30) DEFAULT 'pending',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 9. email_templates
CREATE TABLE IF NOT EXISTS public.email_templates (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    template_name varchar(255) NOT NULL,
    template_code varchar(100) UNIQUE,
    category varchar(100),
    subject_template text,
    html_body_template text,
    text_body_template text,
    available_placeholders_json jsonb DEFAULT '[]'::jsonb,
    default_signature_id uuid,
    version integer DEFAULT 1,
    is_system_template boolean DEFAULT false,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    created_by uuid,
    updated_at timestamptz DEFAULT now(),
    updated_by uuid
);

-- 10. email_template_versions
CREATE TABLE IF NOT EXISTS public.email_template_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_template_id uuid NOT NULL REFERENCES public.email_templates(id) ON DELETE CASCADE,
    version_number integer NOT NULL,
    subject_template text,
    html_body_template text,
    text_body_template text,
    change_note text,
    created_at timestamptz DEFAULT now(),
    created_by uuid
);

-- 11. email_signatures
CREATE TABLE IF NOT EXISTS public.email_signatures (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    signature_name varchar(255) NOT NULL,
    html_signature text,
    text_signature text,
    department varchar(100),
    is_default boolean DEFAULT false,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    created_by uuid,
    updated_at timestamptz DEFAULT now(),
    updated_by uuid
);

-- 12. email_groups
CREATE TABLE IF NOT EXISTS public.email_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    group_name varchar(255) NOT NULL,
    group_type varchar(50) DEFAULT 'static',
    description text,
    is_dynamic boolean DEFAULT false,
    dynamic_filter_json jsonb,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    created_by uuid,
    updated_at timestamptz DEFAULT now(),
    updated_by uuid
);

-- 13. email_group_members
CREATE TABLE IF NOT EXISTS public.email_group_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_group_id uuid NOT NULL REFERENCES public.email_groups(id) ON DELETE CASCADE,
    email_address varchar(255) NOT NULL,
    display_name varchar(255),
    linked_entity_type varchar(50),
    linked_entity_id uuid,
    consent_status varchar(30) DEFAULT 'unknown',
    consent_source varchar(100),
    consent_at timestamptz,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(email_group_id, email_address)
);

-- 14. email_campaigns
CREATE TABLE IF NOT EXISTS public.email_campaigns (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    campaign_name varchar(255) NOT NULL,
    email_account_id uuid REFERENCES public.email_accounts(id),
    email_template_id uuid REFERENCES public.email_templates(id),
    subject_override text,
    html_body_override text,
    text_body_override text,
    status varchar(30) DEFAULT 'draft', -- draft, validating, scheduled, queued, running, paused, completed, cancelled, failed
    scheduled_at timestamptz,
    started_at timestamptz,
    completed_at timestamptz,
    paused_at timestamptz,
    cancelled_at timestamptz,
    total_recipients integer DEFAULT 0,
    queued_count integer DEFAULT 0,
    sent_count integer DEFAULT 0,
    delivered_count integer DEFAULT 0,
    failed_count integer DEFAULT 0,
    bounced_count integer DEFAULT 0,
    opened_count integer DEFAULT 0,
    clicked_count integer DEFAULT 0,
    unsubscribed_count integer DEFAULT 0,
    batch_size_override integer,
    delay_override_seconds integer,
    created_by_user_id uuid,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 15. email_campaign_recipients
CREATE TABLE IF NOT EXISTS public.email_campaign_recipients (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_campaign_id uuid NOT NULL REFERENCES public.email_campaigns(id) ON DELETE CASCADE,
    email_address varchar(255) NOT NULL,
    display_name varchar(255),
    linked_entity_type varchar(50),
    linked_entity_id uuid,
    personalisation_json jsonb,
    status varchar(30) DEFAULT 'pending',
    email_message_id uuid,
    queue_item_id uuid,
    sent_at timestamptz,
    delivered_at timestamptz,
    opened_at timestamptz,
    clicked_at timestamptz,
    bounced_at timestamptz,
    unsubscribed_at timestamptz,
    failure_message text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(email_campaign_id, email_address)
);

-- 16. email_queue
CREATE TABLE IF NOT EXISTS public.email_queue (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    queue_type varchar(30) DEFAULT 'normal', -- normal, transactional, otp, broadcast, system
    priority integer DEFAULT 5, -- 1=highest, 10=lowest
    email_account_id uuid REFERENCES public.email_accounts(id),
    email_message_id uuid REFERENCES public.email_messages(id),
    email_campaign_id uuid REFERENCES public.email_campaigns(id),
    email_campaign_recipient_id uuid,
    scheduled_at timestamptz,
    available_at timestamptz DEFAULT now(),
    status varchar(30) DEFAULT 'waiting', -- waiting, locked, processing, sent, completed, temporary_failed, permanent_failed, paused, cancelled
    attempt_count integer DEFAULT 0,
    maximum_attempts integer DEFAULT 3,
    locked_at timestamptz,
    locked_by varchar(255),
    processing_started_at timestamptz,
    processing_finished_at timestamptz,
    next_retry_at timestamptz,
    last_error_code varchar(50),
    last_error_message text,
    idempotency_key varchar(255) UNIQUE,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 17. email_send_attempts
CREATE TABLE IF NOT EXISTS public.email_send_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_queue_id uuid REFERENCES public.email_queue(id) ON DELETE CASCADE,
    email_message_id uuid REFERENCES public.email_messages(id),
    attempt_number integer NOT NULL DEFAULT 1,
    started_at timestamptz DEFAULT now(),
    completed_at timestamptz,
    result varchar(30), -- success, temporary_failure, permanent_failure
    provider_response_code varchar(50),
    provider_message_id varchar(255),
    error_category varchar(50),
    safe_error_message text,
    duration_ms integer,
    created_at timestamptz DEFAULT now()
);

-- 18. email_delivery_events
CREATE TABLE IF NOT EXISTS public.email_delivery_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_message_id uuid REFERENCES public.email_messages(id),
    email_message_recipient_id uuid REFERENCES public.email_message_recipients(id),
    email_campaign_id uuid REFERENCES public.email_campaigns(id),
    provider_event_id varchar(255),
    event_type varchar(50) NOT NULL, -- delivered, bounced, complained, opened, clicked, unsubscribed
    event_at timestamptz DEFAULT now(),
    provider_payload_json jsonb,
    created_at timestamptz DEFAULT now()
);

-- 19. email_sync_runs
CREATE TABLE IF NOT EXISTS public.email_sync_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_account_id uuid NOT NULL REFERENCES public.email_accounts(id) ON DELETE CASCADE,
    folder_id uuid REFERENCES public.email_folders(id),
    started_at timestamptz DEFAULT now(),
    completed_at timestamptz,
    status varchar(30) DEFAULT 'running', -- running, completed, failed
    messages_checked integer DEFAULT 0,
    messages_inserted integer DEFAULT 0,
    messages_updated integer DEFAULT 0,
    attachments_downloaded integer DEFAULT 0,
    errors_count integer DEFAULT 0,
    safe_error_message text,
    created_at timestamptz DEFAULT now()
);

-- 20. email_logs
CREATE TABLE IF NOT EXISTS public.email_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    event_type varchar(100) NOT NULL,
    email_account_id uuid,
    email_message_id uuid,
    email_campaign_id uuid,
    queue_item_id uuid,
    user_id uuid,
    source varchar(100),
    ip_address inet,
    user_agent text,
    event_data_json jsonb,
    safe_message text,
    created_at timestamptz DEFAULT now()
);

-- 21. email_settings
CREATE TABLE IF NOT EXISTS public.email_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    setting_scope varchar(50) DEFAULT 'global',
    setting_key varchar(100) NOT NULL UNIQUE,
    setting_value_json jsonb,
    is_sensitive boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 22. email_ai_settings
CREATE TABLE IF NOT EXISTS public.email_ai_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    feature_name varchar(100) NOT NULL UNIQUE,
    is_enabled boolean DEFAULT false,
    approval_required boolean DEFAULT true,
    provider_reference varchar(100),
    model_reference varchar(100),
    prompt_template text,
    language_mode varchar(20) DEFAULT 'auto',
    confidence_threshold numeric(3,2) DEFAULT 0.70,
    auto_send_allowed boolean DEFAULT false,
    maximum_tokens integer DEFAULT 2000,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 23. email_ai_results
CREATE TABLE IF NOT EXISTS public.email_ai_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_message_id uuid REFERENCES public.email_messages(id),
    feature_name varchar(100) NOT NULL,
    result_text text,
    result_json jsonb,
    confidence_score numeric(3,2),
    provider_reference varchar(100),
    model_reference varchar(100),
    approved_by uuid,
    approved_at timestamptz,
    created_at timestamptz DEFAULT now()
);

-- 24. email_suppressions
CREATE TABLE IF NOT EXISTS public.email_suppressions (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_address varchar(255) NOT NULL,
    suppression_type varchar(30) NOT NULL, -- unsubscribe, hard_bounce, complaint, manual_block, invalid_address
    reason text,
    source varchar(100),
    source_reference varchar(255),
    suppressed_at timestamptz DEFAULT now(),
    expires_at timestamptz,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 25. email_unsubscribe_tokens
CREATE TABLE IF NOT EXISTS public.email_unsubscribe_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_address varchar(255) NOT NULL,
    email_campaign_id uuid REFERENCES public.email_campaigns(id),
    token_hash varchar(128) NOT NULL UNIQUE,
    expires_at timestamptz NOT NULL,
    used_at timestamptz,
    created_at timestamptz DEFAULT now()
);

-- 26. email_usage_counters
CREATE TABLE IF NOT EXISTS public.email_usage_counters (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    email_account_id uuid NOT NULL REFERENCES public.email_accounts(id) ON DELETE CASCADE,
    period_type varchar(10) NOT NULL, -- hourly, daily
    period_start timestamptz NOT NULL,
    sent_count integer DEFAULT 0,
    failed_count integer DEFAULT 0,
    recipient_count integer DEFAULT 0,
    critical_sent_count integer DEFAULT 0,
    broadcast_sent_count integer DEFAULT 0,
    updated_at timestamptz DEFAULT now(),
    UNIQUE(email_account_id, period_type, period_start)
);


-- ============ INDEXES ============

CREATE INDEX IF NOT EXISTS idx_email_accounts_active ON public.email_accounts(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_email_accounts_default_manual ON public.email_accounts(default_for_manual) WHERE default_for_manual = true;
CREATE INDEX IF NOT EXISTS idx_email_accounts_default_transactional ON public.email_accounts(default_for_transactional) WHERE default_for_transactional = true;

CREATE INDEX IF NOT EXISTS idx_email_folders_account ON public.email_folders(email_account_id);
CREATE INDEX IF NOT EXISTS idx_email_folders_type ON public.email_folders(email_account_id, folder_type);

CREATE INDEX IF NOT EXISTS idx_email_messages_account_folder ON public.email_messages(email_account_id, folder_id);
CREATE INDEX IF NOT EXISTS idx_email_messages_thread ON public.email_messages(thread_id);
CREATE INDEX IF NOT EXISTS idx_email_messages_status ON public.email_messages(status);
CREATE INDEX IF NOT EXISTS idx_email_messages_direction ON public.email_messages(direction);
CREATE INDEX IF NOT EXISTS idx_email_messages_received_at ON public.email_messages(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_messages_sent_at ON public.email_messages(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_messages_is_read ON public.email_messages(email_account_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_email_messages_is_starred ON public.email_messages(email_account_id, is_starred) WHERE is_starred = true;
CREATE INDEX IF NOT EXISTS idx_email_messages_message_id_header ON public.email_messages(message_id_header);
CREATE INDEX IF NOT EXISTS idx_email_messages_unique_incoming ON public.email_messages(email_account_id, folder_id, uid_validity, remote_uid) WHERE remote_uid IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_email_messages_source ON public.email_messages(source_type);

CREATE INDEX IF NOT EXISTS idx_email_recipients_message ON public.email_message_recipients(email_message_id);
CREATE INDEX IF NOT EXISTS idx_email_recipients_address ON public.email_message_recipients(email_address);

CREATE INDEX IF NOT EXISTS idx_email_attachments_message ON public.email_attachments(email_message_id);

CREATE INDEX IF NOT EXISTS idx_email_queue_status ON public.email_queue(status, available_at);
CREATE INDEX IF NOT EXISTS idx_email_queue_account ON public.email_queue(email_account_id, status);
CREATE INDEX IF NOT EXISTS idx_email_queue_campaign ON public.email_queue(email_campaign_id) WHERE email_campaign_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_email_queue_scheduled ON public.email_queue(scheduled_at) WHERE status = 'waiting' AND scheduled_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_email_queue_retry ON public.email_queue(next_retry_at) WHERE status = 'temporary_failed';

CREATE INDEX IF NOT EXISTS idx_email_campaigns_status ON public.email_campaigns(status);
CREATE INDEX IF NOT EXISTS idx_email_campaign_recipients_campaign ON public.email_campaign_recipients(email_campaign_id, status);

CREATE INDEX IF NOT EXISTS idx_email_logs_type ON public.email_logs(event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_logs_account ON public.email_logs(email_account_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_logs_user ON public.email_logs(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_email_suppressions_address ON public.email_suppressions(email_address, is_active);
CREATE INDEX IF NOT EXISTS idx_email_suppressions_type ON public.email_suppressions(suppression_type, is_active);

CREATE INDEX IF NOT EXISTS idx_email_usage_counters_lookup ON public.email_usage_counters(email_account_id, period_type, period_start);

CREATE INDEX IF NOT EXISTS idx_email_sync_runs_account ON public.email_sync_runs(email_account_id, started_at DESC);


-- ============ TRIGGERS ============

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.email_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
  tbl text;
BEGIN
  FOR tbl IN SELECT unnest(ARRAY[
    'email_provider_presets', 'email_accounts', 'email_account_secrets',
    'email_folders', 'email_threads', 'email_messages', 'email_message_recipients',
    'email_attachments', 'email_templates', 'email_signatures', 'email_groups',
    'email_group_members', 'email_campaigns', 'email_campaign_recipients',
    'email_queue', 'email_settings', 'email_ai_settings', 'email_suppressions'
  ])
  LOOP
    EXECUTE format('
      DROP TRIGGER IF EXISTS trg_%s_updated_at ON public.%I;
      CREATE TRIGGER trg_%s_updated_at
        BEFORE UPDATE ON public.%I
        FOR EACH ROW EXECUTE FUNCTION public.email_update_timestamp();
    ', tbl, tbl, tbl, tbl);
  END LOOP;
END $$;

-- Default account exclusivity trigger
CREATE OR REPLACE FUNCTION public.email_enforce_single_default()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.default_for_manual = true THEN
    UPDATE public.email_accounts SET default_for_manual = false WHERE id != NEW.id AND default_for_manual = true;
  END IF;
  IF NEW.default_for_transactional = true THEN
    UPDATE public.email_accounts SET default_for_transactional = false WHERE id != NEW.id AND default_for_transactional = true;
  END IF;
  IF NEW.default_for_otp = true THEN
    UPDATE public.email_accounts SET default_for_otp = false WHERE id != NEW.id AND default_for_otp = true;
  END IF;
  IF NEW.default_for_broadcast = true THEN
    UPDATE public.email_accounts SET default_for_broadcast = false WHERE id != NEW.id AND default_for_broadcast = true;
  END IF;
  IF NEW.default_for_incoming = true THEN
    UPDATE public.email_accounts SET default_for_incoming = false WHERE id != NEW.id AND default_for_incoming = true;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_email_accounts_single_default ON public.email_accounts;
CREATE TRIGGER trg_email_accounts_single_default
  BEFORE INSERT OR UPDATE ON public.email_accounts
  FOR EACH ROW EXECUTE FUNCTION public.email_enforce_single_default();


-- ============ ROW-LEVEL SECURITY ============

ALTER TABLE public.email_provider_presets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_account_secrets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_message_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_template_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_signatures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_campaign_recipients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_send_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_delivery_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_sync_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_ai_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_ai_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_suppressions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_unsubscribe_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_usage_counters ENABLE ROW LEVEL SECURITY;

-- Service role has full access (for Edge Functions / backend)
-- Authenticated users get read access to non-secret tables via RPC

-- Block ALL client access to secrets table
CREATE POLICY email_secrets_no_client_access ON public.email_account_secrets
  FOR ALL TO anon, authenticated
  USING (false);

-- Service role bypass (implicit via RLS bypass for service_role)

-- Allow authenticated users read access to non-sensitive email tables
CREATE POLICY email_presets_read ON public.email_provider_presets
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_accounts_read ON public.email_accounts
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_folders_read ON public.email_folders
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_threads_read ON public.email_threads
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_messages_read ON public.email_messages
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_recipients_read ON public.email_message_recipients
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_attachments_read ON public.email_attachments
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_templates_read ON public.email_templates
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_template_versions_read ON public.email_template_versions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_signatures_read ON public.email_signatures
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_groups_read ON public.email_groups
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_group_members_read ON public.email_group_members
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_campaigns_read ON public.email_campaigns
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_campaign_recipients_read ON public.email_campaign_recipients
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_queue_read ON public.email_queue
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_send_attempts_read ON public.email_send_attempts
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_delivery_events_read ON public.email_delivery_events
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_sync_runs_read ON public.email_sync_runs
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_logs_read ON public.email_logs
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_settings_read ON public.email_settings
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_ai_settings_read ON public.email_ai_settings
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_ai_results_read ON public.email_ai_results
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_suppressions_read ON public.email_suppressions
  FOR SELECT TO authenticated USING (true);

CREATE POLICY email_usage_counters_read ON public.email_usage_counters
  FOR SELECT TO authenticated USING (true);


-- ============ DEFAULT DATA ============

-- Insert provider presets
INSERT INTO public.email_provider_presets (provider_code, provider_name, smtp_host, smtp_port, smtp_encryption, imap_host, imap_port, imap_encryption, supports_delivery_webhooks, documentation_note) VALUES
  ('namecheap', 'Namecheap Private Email', 'mail.privateemail.com', 587, 'tls', 'mail.privateemail.com', 993, 'ssl', false, 'Namecheap Private Email - standard SMTP/IMAP'),
  ('gmail', 'Gmail / Google Workspace', 'smtp.gmail.com', 587, 'tls', 'imap.gmail.com', 993, 'ssl', false, 'Requires App Password or OAuth2'),
  ('outlook', 'Microsoft 365 / Outlook', 'smtp.office365.com', 587, 'tls', 'outlook.office365.com', 993, 'ssl', false, 'Requires OAuth2 or App Password'),
  ('brevo', 'Brevo (Sendinblue)', 'smtp-relay.brevo.com', 587, 'tls', NULL, NULL, NULL, true, 'Brevo SMTP relay - supports webhooks'),
  ('ses', 'Amazon SES', 'email-smtp.us-east-1.amazonaws.com', 587, 'tls', NULL, NULL, NULL, true, 'AWS SES - region-specific SMTP endpoint'),
  ('custom', 'Custom SMTP/IMAP', NULL, 587, 'tls', NULL, 993, 'ssl', false, 'Custom server - configure manually')
ON CONFLICT (provider_code) DO NOTHING;

-- Insert default email settings
INSERT INTO public.email_settings (setting_key, setting_value_json, is_sensitive) VALUES
  ('sync_interval_seconds', '120', false),
  ('queue_processing_interval_seconds', '60', false),
  ('default_batch_size', '10', false),
  ('default_send_delay_seconds', '2', false),
  ('default_retry_count', '3', false),
  ('retry_backoff_multiplier', '2', false),
  ('attachment_max_size_bytes', '26214400', false),
  ('attachment_allowed_types', '["pdf","doc","docx","xls","xlsx","ppt","pptx","txt","csv","jpg","jpeg","png","gif","webp","zip","rar"]', false),
  ('auto_save_draft_interval_seconds', '30', false),
  ('retention_days', '365', false),
  ('default_search_date_range_days', '90', false),
  ('unsubscribe_required_for_broadcast', 'true', false),
  ('log_retention_days', '180', false)
ON CONFLICT (setting_key) DO NOTHING;

-- Insert default AI settings (all disabled)
INSERT INTO public.email_ai_settings (feature_name, is_enabled, approval_required, auto_send_allowed) VALUES
  ('email_summary', false, false, false),
  ('translation', false, false, false),
  ('reply_suggestion', false, true, false),
  ('auto_categorisation', false, false, false),
  ('sentiment_detection', false, false, false),
  ('spam_detection', false, false, false),
  ('priority_detection', false, false, false),
  ('auto_draft', false, true, false),
  ('ticket_suggestion', false, true, false),
  ('auto_reply', false, true, false)
ON CONFLICT (feature_name) DO NOTHING;


-- ============ STORAGE BUCKET ============

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'email-attachments',
  'email-attachments',
  false,
  26214400,
  ARRAY['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','image/jpeg','image/png','image/gif','image/webp','text/plain','text/csv','application/zip']
)
ON CONFLICT (id) DO NOTHING;
