# AQURA EMAIL MANAGEMENT SYSTEM
## Complete AI Coding Agent Implementation Specification

**Document purpose:** Build, integrate, deploy, and validate a complete production-ready Email Management System inside Aqura.

**Primary instruction to the coding agent:** Complete the entire job end to end. Do not stop after creating UI mock-ups, database tables, or partial integrations. The final result must allow authorised Aqura users to configure an email account from the database-driven interface, send and receive real emails, manage inboxes, send broadcasts through a controlled queue, and view complete logs and reports.

---

# 1. Project Objective

Create a new main sidebar section named **Email**, following the same architecture, navigation behaviour, permission logic, window system, and visual style as the existing **WhatsApp** section.

The Email module must support:

- Multiple email accounts.
- SMTP sending.
- IMAP receiving and synchronisation.
- Inbox, Sent, Drafts, Spam, Archive, Trash, Starred, and custom folders.
- Compose, Reply, Reply All, Forward, Save Draft, Delete, Archive, and Search.
- Attachments.
- Reusable email templates.
- Reusable signatures.
- Email groups.
- Email broadcasts and campaigns.
- Rate-controlled background queues.
- Scheduled emails.
- OTP and transactional emails.
- Delivery, failure, usage, and activity logs.
- Configurable AI-assisted email features.
- Future integration with customers, suppliers, employees, sales, invoices, support tickets, and CRM records.

The implementation must be modular, secure, database-driven, and extensible to Namecheap Private Email, Brevo, Amazon SES, Gmail, Microsoft 365, and custom SMTP/IMAP providers.

---

# 2. Non-Negotiable Rules

The following rules are mandatory:

1. **Do not hardcode any email account, email address, SMTP setting, IMAP setting, password, provider key, rate limit, retry limit, sender name, reply-to address, or default account anywhere in the frontend, backend, Edge Functions, worker services, or source code.**

2. All email account configuration must be created and maintained through Aqura and stored in the database.

3. SMTP and IMAP credentials must be encrypted before being stored.

4. The credential-encryption master key must never be hardcoded and must never be stored in a client-readable table. Store it as a secure server-side secret or environment variable.

5. The frontend must never receive SMTP passwords, IMAP passwords, encryption keys, service-role keys, SSH keys, or decrypted secrets.

6. All normal database reads and writes from the frontend must use the project’s existing RPC architecture. Do not add direct frontend SQL queries.

7. Reuse the existing Aqura authentication, permission, sidebar, window, theme, component, migration, logging, and storage architecture.

8. Use the existing secure SSH/database deployment mechanism already available in the codebase to apply migrations and deploy backend components. Do not create a second unrelated migration mechanism.

9. Never expose the existing SSH private key in the frontend, logs, generated documentation, browser bundle, or database.

10. Every visible final-action button must have a separate permission entry.

11. A subsection must remain hidden when the user has no permission for any button inside it.

12. The entire Email main section must remain hidden when the user has no permission for any Email button.

13. Super Admin must have full access according to the existing Super Admin behaviour.

14. The module must use the Aqura **light theme** and the existing theme system.

15. Buttons inside Email windows must use a consistent **light glassmorphism style** and must remain readable, accessible, and responsive.

16. Do not finish with placeholder data, mocked API calls, fake email statuses, or non-functional buttons.

17. Do not alter or break the existing WhatsApp module, HR module, permission system, login system, sidebar, or window manager.

---

# 3. Mandatory Discovery Phase

Before changing code, inspect and document the following existing implementation patterns:

- WhatsApp sidebar registration.
- Main-section and subsection configuration.
- Existing button registration system.
- Permission keys and permission-loading logic.
- Rules that hide unauthorised main sections and subsections.
- Window manager.
- Window lifecycle and state restoration.
- Existing modal and confirmation components.
- Existing data-table, search, filter, pagination, date-picker, editor, upload, and toast components.
- Current light and dark theme tokens.
- Existing glassmorphism or translucent button styles.
- Current RPC conventions.
- Existing database migration naming and deployment flow.
- Existing Supabase Edge Function structure and deployment scripts.
- Existing scheduled-function, cron, queue, or worker architecture.
- Existing storage-bucket structure and file-access policies.
- Existing audit-log architecture.
- Existing encryption or secret-management utilities.
- Existing SSH connection and migration execution mechanism.

Create a short internal implementation map before coding. Do not ask the user to explain architecture that can be discovered from the repository.

When an existing reusable pattern is available, use it instead of creating a parallel pattern.

---

# 4. Required Sidebar Structure

Create a new main sidebar section:

## Email

Create these subsections and buttons.

### 4.1 Dashboard

- **Email Dashboard**

### 4.2 Management

- **Email Accounts**
- **Email Templates**
- **Email Signatures**
- **Email Groups**
- **Email Settings**
- **AI Email Settings**

### 4.3 Operations

- **Email Centre**
- **Compose Email**
- **Broadcast Email**
- **Email Queue**
- **Scheduled Emails**

### 4.4 Reports

- **Email Logs**
- **Delivery Reports**
- **Campaign Reports**
- **Failed Emails**

Every button must:

- Be registered in the existing button registry.
- Have a unique stable permission key.
- Open a separate Aqura window.
- Restore or focus an already-open window instead of opening duplicates, following the existing window-manager behaviour.
- Use the existing window header, resizing, minimising, maximising, closing, and state-management conventions.

---

# 5. Suggested Permission Keys

Use the project’s exact permission naming convention after inspecting it. The following names describe the required scope:

- `email.dashboard.view`
- `email.accounts.view`
- `email.accounts.create`
- `email.accounts.edit`
- `email.accounts.delete`
- `email.accounts.test_smtp`
- `email.accounts.test_imap`
- `email.accounts.set_default`
- `email.templates.view`
- `email.templates.create`
- `email.templates.edit`
- `email.templates.delete`
- `email.signatures.view`
- `email.signatures.create`
- `email.signatures.edit`
- `email.signatures.delete`
- `email.groups.view`
- `email.groups.create`
- `email.groups.edit`
- `email.groups.delete`
- `email.settings.view`
- `email.settings.edit`
- `email.ai_settings.view`
- `email.ai_settings.edit`
- `email.centre.view`
- `email.compose.open`
- `email.compose.send`
- `email.compose.save_draft`
- `email.broadcast.view`
- `email.broadcast.create`
- `email.broadcast.start`
- `email.broadcast.pause`
- `email.broadcast.resume`
- `email.broadcast.cancel`
- `email.queue.view`
- `email.queue.pause`
- `email.queue.resume`
- `email.queue.retry`
- `email.queue.cancel`
- `email.scheduled.view`
- `email.scheduled.create`
- `email.scheduled.edit`
- `email.scheduled.cancel`
- `email.logs.view`
- `email.delivery_reports.view`
- `email.campaign_reports.view`
- `email.failed.view`
- `email.failed.retry`

Do not grant a user access to a protected final action merely because the parent window is visible.

---

# 6. UI and Visual Design Standard

## 6.1 General Theme

The Email module must visually match Aqura and use the current light theme by default.

Use:

- Light neutral page background.
- White or lightly translucent window surfaces.
- Soft shadows.
- Subtle borders.
- Clear typography hierarchy.
- Adequate whitespace.
- Existing Aqura spacing and radius tokens.
- Existing Aqura icons or icon library.
- Existing responsive behaviour.

Do not introduce a separate visual design language.

## 6.2 Glassmorphism Buttons Inside Windows

All primary action buttons inside Email windows must use a light glassmorphism style consistent with the existing system.

Required characteristics:

- Light translucent background.
- Backdrop blur where supported.
- Soft border.
- Soft shadow.
- Clearly visible text and icon.
- Strong hover state.
- Visible keyboard-focus state.
- Pressed state.
- Disabled state.
- Loading state.
- Accessible contrast.

Use semantic variants:

- Primary.
- Secondary.
- Success.
- Warning.
- Danger.
- Neutral.

Examples of actions using this style:

- Create.
- Save.
- Send.
- Test SMTP.
- Test IMAP.
- Sync Now.
- Reply.
- Forward.
- Broadcast.
- Pause.
- Resume.
- Retry.
- Cancel.
- Delete.

Do not use excessive transparency that makes buttons difficult to read.

## 6.3 Window Behaviour

Each Email button must open a standard Aqura window.

Windows must support the existing behaviour for:

- Dragging.
- Resizing.
- Minimising.
- Maximising.
- Closing.
- Restoring.
- Z-index/focus.
- Remembering state when the existing system supports it.
- Unsaved-change warning before close.

## 6.4 Tables

Use the existing table component and provide:

- Search.
- Filters.
- Sorting.
- Pagination.
- Column selection where supported.
- Loading skeleton.
- Empty state.
- Error state.
- Row actions.
- Responsive overflow handling.
- Export only where permission allows.

---

# 7. Technical Architecture

Use this logical flow:

```text
Aqura Frontend
    |
    | RPC / authenticated backend request
    v
Database + Backend API / Edge Function
    |
    | reads active account configuration from database
    | decrypts credentials only on server side
    v
SMTP / IMAP Provider
    |
    v
External Email Recipient or Mailbox
```

Incoming email flow:

```text
External Sender
    |
    v
Configured Mailbox
    |
    | IMAP sync worker
    v
Aqura Email Tables + Attachment Storage
    |
    v
Email Centre
```

Outgoing email flow:

```text
Aqura User or System Event
    |
    v
RPC creates draft or queue item
    |
    v
Queue Processor / Send Service
    |
    | loads account settings from database
    | decrypts credentials server-side
    | enforces limits
    v
SMTP Provider
    |
    v
Recipient
```

The database must be the authoritative source for all email configuration and Aqura’s synchronised message records.

The external mailbox remains the source of truth for actual mailbox delivery and folders.

---

# 8. Runtime Decision: Edge Functions and Email Worker

Create all required Edge Functions.

However, the coding agent must first verify whether the current Supabase Edge Function runtime can reliably perform:

- Raw SMTP connections.
- TLS SMTP authentication.
- IMAP connections.
- Long-running mailbox synchronisation.
- Large attachment streaming.

If the Edge Function runtime fully supports the required SMTP and IMAP libraries, implement the work there.

If raw SMTP or IMAP is unreliable or unsupported in the Edge runtime:

1. Create a secure server-side Email Worker service using the project’s existing server infrastructure.
2. Deploy it through the existing SSH/deployment mechanism.
3. Keep Edge Functions as authenticated orchestration endpoints.
4. Let Edge Functions enqueue jobs and trigger or communicate with the worker.
5. Never move SMTP or IMAP credentials to the frontend.
6. Document the final runtime choice in the completion report.

Do not pretend SMTP/IMAP integration is complete if only the UI or database layer exists.

---

# 9. Required Edge Functions

Use the project’s existing naming and folder conventions. Create the following logical functions, combining them only when it improves maintainability without weakening permissions or logging.

## 9.1 `email-account-test`

Purpose:

- Test SMTP.
- Test IMAP.
- Return a safe result.
- Never return credentials.
- Log the test.
- Apply timeout protection.

## 9.2 `email-send`

Purpose:

- Send one normal, transactional, reply, or forwarded email.
- Load account settings dynamically from the database.
- Enforce permission, rate, recipient, suppression, and attachment rules.
- Create send logs.
- Update message and queue statuses.
- Use idempotency protection.

## 9.3 `email-queue-processor`

Purpose:

- Process queued outgoing emails.
- Respect account-level hourly and daily limits.
- Reserve capacity for critical messages.
- Apply batch size and delay settings.
- Retry temporary failures.
- Stop retrying permanent failures.
- Maintain an execution lock to prevent duplicate workers.

## 9.4 `email-imap-sync`

Purpose:

- Connect to active IMAP accounts.
- Synchronise folders and new messages.
- Store message headers and bodies.
- Store attachments.
- Update read, flagged, deleted, and folder states when supported.
- Prevent duplicates using account, folder, UIDVALIDITY, UID, and Message-ID.
- Maintain sync cursors.
- Log sync errors safely.

## 9.5 `email-scheduled-sender`

Purpose:

- Find due scheduled emails.
- Move them into the queue.
- Use idempotent processing.
- Respect account limits and campaign status.

## 9.6 `email-broadcast-processor`

Purpose:

- Expand campaign recipients.
- Remove invalid, unsubscribed, bounced, duplicated, and suppressed addresses.
- Personalise templates.
- Add each recipient to the queue.
- Process gradually, never all at once.
- Maintain campaign totals and progress.

## 9.7 `email-retry-processor`

Purpose:

- Requeue eligible temporary failures.
- Use exponential backoff.
- Respect maximum retry count.
- Avoid retry storms.

## 9.8 `email-maintenance`

Purpose:

- Clear expired locks.
- Clean temporary upload files.
- Apply retention settings.
- Reconcile stuck queue jobs.
- Recalculate usage summaries when needed.

## 9.9 `email-ai-process`

Purpose:

- Generate summaries, translations, reply suggestions, categories, sentiment, priority, or draft replies when enabled.
- Never auto-send unless a separate explicit setting and permission authorise it.
- Log AI activity and the model/provider used.
- Protect against prompt injection from incoming email content.

## 9.10 `email-webhook-receiver`

Create this when a configured provider supports delivery, bounce, complaint, open, or click webhooks.

Requirements:

- Verify webhook signature.
- Reject unauthenticated calls.
- Store raw event metadata safely.
- Update delivery status.
- Update suppression lists for hard bounces and complaints.
- Remain optional for providers that do not support webhooks.

---

# 10. Scheduling and Background Processing

Create the required scheduled jobs using the project’s existing scheduler, Supabase Cron, `pg_cron`, or existing worker scheduler.

Recommended defaults must be stored in the database and editable by authorised users. Do not hardcode them.

Logical schedules:

- IMAP sync: configurable, for example every 2–5 minutes.
- Queue processor: configurable, for example every minute.
- Scheduled sender: configurable, for example every minute.
- Retry processor: configurable, for example every 5 minutes.
- Maintenance: configurable, for example hourly or daily.

The scheduler must:

- Use locks.
- Prevent overlapping executions.
- Record start time, finish time, result, processed count, and error count.
- Fail safely.
- Avoid repeatedly processing the same job.

---

# 11. Database Design

Follow the project’s exact naming convention. If the project requires a prefix, apply it consistently to every Email table, view, RPC, trigger, sequence, and policy.

Use UUID primary keys unless the existing project standard requires otherwise.

Include standard audit columns according to the existing project pattern:

- `id`
- `created_at`
- `created_by`
- `updated_at`
- `updated_by`
- `is_active`
- soft-delete columns where appropriate

## 11.1 `email_provider_presets`

Purpose: Database-driven provider presets.

Suggested columns:

- `id`
- `provider_code`
- `provider_name`
- `smtp_host`
- `smtp_port`
- `smtp_encryption`
- `imap_host`
- `imap_port`
- `imap_encryption`
- `supports_delivery_webhooks`
- `supports_open_tracking`
- `supports_click_tracking`
- `supports_api_send`
- `documentation_note`
- `is_active`

Provider hosts and ports must be editable in the database and must not be required to remain in source code.

## 11.2 `email_accounts`

Public account configuration without raw secrets.

Suggested columns:

- `id`
- `account_name`
- `provider_preset_id`
- `email_address`
- `from_name`
- `reply_to_address`
- `smtp_host`
- `smtp_port`
- `smtp_encryption`
- `smtp_username`
- `imap_host`
- `imap_port`
- `imap_encryption`
- `imap_username`
- `default_for_manual`
- `default_for_transactional`
- `default_for_otp`
- `default_for_broadcast`
- `default_for_incoming`
- `hourly_send_limit`
- `daily_send_limit`
- `maximum_recipients_per_message`
- `reserve_critical_per_hour`
- `queue_batch_size`
- `minimum_delay_seconds`
- `maximum_concurrent_sends`
- `maximum_retry_count`
- `sync_enabled`
- `send_enabled`
- `last_smtp_test_at`
- `last_smtp_test_status`
- `last_imap_test_at`
- `last_imap_test_status`
- `last_sync_at`
- `last_sync_status`
- `notes`
- audit fields

No account must be automatically hardcoded as default.

## 11.3 `email_account_secrets`

Server-only encrypted credential storage.

Suggested columns:

- `id`
- `email_account_id`
- `encrypted_smtp_password`
- `encrypted_imap_password`
- `encrypted_api_key`
- `encrypted_webhook_secret`
- `encryption_version`
- `key_reference`
- `rotated_at`
- audit fields

Security rules:

- No client role may select this table.
- No normal frontend RPC may return these values.
- Only service-role backend code may read and decrypt them.
- Masked values may be shown in the UI, such as `••••••••`, without revealing length or content.

## 11.4 `email_folders`

Suggested columns:

- `id`
- `email_account_id`
- `remote_folder_name`
- `display_name`
- `folder_type`
- `delimiter`
- `uid_validity`
- `last_synced_uid`
- `last_sync_at`
- `is_selectable`
- `is_subscribed`
- audit fields

Folder types:

- inbox
- sent
- drafts
- trash
- spam
- archive
- starred
- custom

## 11.5 `email_threads`

Suggested columns:

- `id`
- `email_account_id`
- `normalised_subject`
- `latest_message_at`
- `message_count`
- `unread_count`
- `participants_json`
- `linked_entity_type`
- `linked_entity_id`
- audit fields

## 11.6 `email_messages`

Suggested columns:

- `id`
- `email_account_id`
- `folder_id`
- `thread_id`
- `remote_uid`
- `uid_validity`
- `message_id_header`
- `in_reply_to_header`
- `references_header`
- `direction`
- `status`
- `subject`
- `from_name`
- `from_address`
- `reply_to_address`
- `html_body`
- `text_body`
- `body_preview`
- `sent_at`
- `received_at`
- `scheduled_at`
- `is_read`
- `is_starred`
- `is_flagged`
- `is_draft`
- `is_archived`
- `is_deleted`
- `priority`
- `importance`
- `has_attachments`
- `spam_score`
- `linked_entity_type`
- `linked_entity_id`
- `source_type`
- `source_reference`
- `created_by_user_id`
- audit fields

Create unique protection against duplicate incoming messages.

## 11.7 `email_message_recipients`

Suggested columns:

- `id`
- `email_message_id`
- `recipient_type`
- `display_name`
- `email_address`
- `delivery_status`
- `delivered_at`
- `opened_at`
- `clicked_at`
- `bounced_at`
- `complained_at`
- `failure_code`
- `failure_message`
- audit fields

Recipient types:

- to
- cc
- bcc

## 11.8 `email_attachments`

Suggested columns:

- `id`
- `email_message_id`
- `file_name`
- `original_file_name`
- `content_type`
- `file_size`
- `storage_bucket`
- `storage_path`
- `content_id`
- `is_inline`
- `checksum`
- `scan_status`
- audit fields

## 11.9 `email_templates`

Suggested columns:

- `id`
- `template_name`
- `template_code`
- `category`
- `subject_template`
- `html_body_template`
- `text_body_template`
- `available_placeholders_json`
- `default_signature_id`
- `version`
- `is_system_template`
- `is_active`
- audit fields

## 11.10 `email_template_versions`

Store version history for templates.

Suggested columns:

- `id`
- `email_template_id`
- `version_number`
- `subject_template`
- `html_body_template`
- `text_body_template`
- `change_note`
- audit fields

## 11.11 `email_signatures`

Suggested columns:

- `id`
- `signature_name`
- `html_signature`
- `text_signature`
- `department`
- `is_default`
- `is_active`
- audit fields

## 11.12 `email_groups`

Suggested columns:

- `id`
- `group_name`
- `group_type`
- `description`
- `is_dynamic`
- `dynamic_filter_json`
- `is_active`
- audit fields

## 11.13 `email_group_members`

Suggested columns:

- `id`
- `email_group_id`
- `email_address`
- `display_name`
- `linked_entity_type`
- `linked_entity_id`
- `consent_status`
- `consent_source`
- `consent_at`
- `is_active`
- audit fields

Prevent duplicate active addresses inside the same group.

## 11.14 `email_campaigns`

Suggested columns:

- `id`
- `campaign_name`
- `email_account_id`
- `email_template_id`
- `subject_override`
- `html_body_override`
- `text_body_override`
- `status`
- `scheduled_at`
- `started_at`
- `completed_at`
- `paused_at`
- `cancelled_at`
- `total_recipients`
- `queued_count`
- `sent_count`
- `delivered_count`
- `failed_count`
- `bounced_count`
- `opened_count`
- `clicked_count`
- `unsubscribed_count`
- `batch_size_override`
- `delay_override_seconds`
- `created_by_user_id`
- audit fields

Statuses:

- draft
- validating
- scheduled
- queued
- running
- paused
- completed
- cancelled
- failed

## 11.15 `email_campaign_recipients`

Suggested columns:

- `id`
- `email_campaign_id`
- `email_address`
- `display_name`
- `linked_entity_type`
- `linked_entity_id`
- `personalisation_json`
- `status`
- `email_message_id`
- `queue_item_id`
- `sent_at`
- `delivered_at`
- `opened_at`
- `clicked_at`
- `bounced_at`
- `unsubscribed_at`
- `failure_message`
- audit fields

## 11.16 `email_queue`

Suggested columns:

- `id`
- `queue_type`
- `priority`
- `email_account_id`
- `email_message_id`
- `email_campaign_id`
- `email_campaign_recipient_id`
- `scheduled_at`
- `available_at`
- `status`
- `attempt_count`
- `maximum_attempts`
- `locked_at`
- `locked_by`
- `processing_started_at`
- `processing_finished_at`
- `next_retry_at`
- `last_error_code`
- `last_error_message`
- `idempotency_key`
- audit fields

Statuses:

- waiting
- locked
- processing
- sent
- completed
- temporary_failed
- permanent_failed
- paused
- cancelled

## 11.17 `email_send_attempts`

Suggested columns:

- `id`
- `email_queue_id`
- `email_message_id`
- `attempt_number`
- `started_at`
- `completed_at`
- `result`
- `provider_response_code`
- `provider_message_id`
- `error_category`
- `safe_error_message`
- `duration_ms`
- audit fields

## 11.18 `email_delivery_events`

Suggested columns:

- `id`
- `email_message_id`
- `email_message_recipient_id`
- `email_campaign_id`
- `provider_event_id`
- `event_type`
- `event_at`
- `provider_payload_json`
- audit fields

## 11.19 `email_sync_runs`

Suggested columns:

- `id`
- `email_account_id`
- `folder_id`
- `started_at`
- `completed_at`
- `status`
- `messages_checked`
- `messages_inserted`
- `messages_updated`
- `attachments_downloaded`
- `errors_count`
- `safe_error_message`
- audit fields

## 11.20 `email_logs`

Use as the central functional audit log.

Suggested columns:

- `id`
- `event_type`
- `email_account_id`
- `email_message_id`
- `email_campaign_id`
- `queue_item_id`
- `user_id`
- `source`
- `ip_address`
- `user_agent`
- `event_data_json`
- `safe_message`
- `created_at`

Never store decrypted passwords or secret values in logs.

## 11.21 `email_settings`

Suggested columns:

- `id`
- `setting_scope`
- `setting_key`
- `setting_value_json`
- `is_sensitive`
- audit fields

Settings include:

- Global sync interval.
- Default page size.
- Attachment size limit.
- Allowed attachment types.
- Retention period.
- Queue defaults.
- Broadcast defaults.
- Tracking defaults.
- Unsubscribe policy.
- Auto-save draft interval.
- Preview text length.
- Maximum search range.
- Notification settings.

## 11.22 `email_ai_settings`

Suggested columns:

- `id`
- `feature_name`
- `is_enabled`
- `approval_required`
- `provider_reference`
- `model_reference`
- `prompt_template`
- `language_mode`
- `confidence_threshold`
- `auto_send_allowed`
- `maximum_tokens`
- audit fields

AI must be disabled by default unless the existing project has an explicit safe default.

## 11.23 `email_ai_results`

Suggested columns:

- `id`
- `email_message_id`
- `feature_name`
- `result_text`
- `result_json`
- `confidence_score`
- `provider_reference`
- `model_reference`
- `approved_by`
- `approved_at`
- audit fields

## 11.24 `email_suppressions`

Suggested columns:

- `id`
- `email_address`
- `suppression_type`
- `reason`
- `source`
- `source_reference`
- `suppressed_at`
- `expires_at`
- `is_active`
- audit fields

Types:

- unsubscribe
- hard_bounce
- complaint
- manual_block
- invalid_address

## 11.25 `email_unsubscribe_tokens`

Suggested columns:

- `id`
- `email_address`
- `email_campaign_id`
- `token_hash`
- `expires_at`
- `used_at`
- audit fields

Store only a hash of the public token.

## 11.26 `email_usage_counters`

Suggested columns:

- `id`
- `email_account_id`
- `period_type`
- `period_start`
- `sent_count`
- `failed_count`
- `recipient_count`
- `critical_sent_count`
- `broadcast_sent_count`
- `updated_at`

Use transactional updates or views to prevent incorrect counts.

---

# 12. Database Constraints and Indexes

Create all necessary constraints and indexes, including:

- Unique email address rules where appropriate.
- One default account per purpose.
- Unique incoming message identity.
- Unique campaign recipient per campaign.
- Unique queue idempotency key.
- Search indexes for sender, recipient, subject, preview, status, and dates.
- Indexes for queue status and available time.
- Indexes for scheduled emails.
- Indexes for campaign status.
- Indexes for unread messages.
- Indexes for folder/account sync.
- Indexes for linked entity type and ID.
- Indexes for suppression checks.

Use PostgreSQL full-text search if it matches the current project architecture.

Create triggers for:

- Updated timestamps.
- Audit fields.
- Default-account exclusivity.
- Usage counters where appropriate.
- Thread counters.
- Campaign counters.
- Safe queue status transitions.

---

# 13. Row-Level Security and Access Control

Enable RLS according to the existing project security model.

Requirements:

- Users can read only data allowed by their Email permissions and organisational scope.
- Only authorised users can create, edit, or delete account configuration.
- No frontend user can select encrypted secrets.
- No frontend user can call privileged credential-decryption functions.
- Service-role backend functions may access secrets only for the required account and operation.
- BCC addresses must not be exposed to recipients.
- Logs and reports require report permissions.
- Attachment access must use existing authenticated storage rules or signed URLs.
- Broadcast creation and broadcast execution must be separately protected.
- AI settings and AI execution must be separately protected.
- Cross-branch or cross-company visibility must follow the existing Aqura data-isolation rules.

---

# 14. Required RPC Functions

Follow the existing RPC naming pattern. Create complete RPC coverage for every frontend operation.

## 14.1 Account RPCs

- List accounts without secrets.
- Get one account without secrets.
- Create account.
- Update account.
- Delete/deactivate account.
- Set default account by purpose.
- Save or rotate encrypted credentials through a secure server endpoint.
- Get masked credential status.
- Request SMTP test.
- Request IMAP test.
- Request manual sync.

## 14.2 Template RPCs

- List templates.
- Get template.
- Create template.
- Update template.
- Delete/deactivate template.
- Save template version.
- Preview template using safe sample data.
- List allowed placeholders.

## 14.3 Signature RPCs

- List signatures.
- Create signature.
- Update signature.
- Delete/deactivate signature.
- Set default signature.

## 14.4 Group RPCs

- List groups.
- Get group.
- Create group.
- Update group.
- Delete/deactivate group.
- Add member.
- Remove member.
- Import members.
- Preview dynamic group count.
- Resolve dynamic group recipients.

## 14.5 Email Centre RPCs

- List folders.
- List messages.
- Get message with recipients and attachments.
- Search messages.
- Mark read/unread.
- Star/unstar.
- Archive/unarchive.
- Move folder.
- Soft delete.
- Restore.
- Save draft.
- Update draft.
- Delete draft.
- Create reply.
- Create reply all.
- Create forward.
- Link or unlink a business entity.
- Request attachment download.

## 14.6 Sending RPCs

- Validate email before sending.
- Queue normal email.
- Queue transactional email.
- Queue OTP email.
- Queue password-reset email.
- Queue verification email.
- Cancel queued message where allowed.
- Schedule email.
- Reschedule email.
- Cancel scheduled email.

## 14.7 Campaign RPCs

- List campaigns.
- Create campaign.
- Update draft campaign.
- Preview recipients.
- Validate campaign.
- Schedule campaign.
- Start campaign.
- Pause campaign.
- Resume campaign.
- Cancel campaign.
- Duplicate campaign.
- Get campaign progress.

## 14.8 Queue RPCs

- List queue items.
- Get queue details.
- Pause eligible item.
- Resume eligible item.
- Retry eligible item.
- Cancel eligible item.
- Bulk retry with permission.
- Get account usage and remaining estimated capacity.

## 14.9 Report RPCs

- Dashboard summary.
- Email logs.
- Delivery report.
- Campaign report.
- Failure report.
- Hourly usage.
- Daily usage.
- Monthly usage.
- Account health.
- Sync health.
- Queue health.

Every RPC must validate permissions server-side. Frontend button hiding is not sufficient security.

---

# 15. Email Accounts Window

Create a complete management window.

## 15.1 Main Table

Columns:

- Account Name.
- Email Address.
- Provider.
- Sending Enabled.
- Receiving Enabled.
- Default Purposes.
- SMTP Status.
- IMAP Status.
- Last Sync.
- Hourly Limit.
- Sent This Hour.
- Remaining Estimated Capacity.
- Status.
- Actions.

## 15.2 Create/Edit Form

Sections:

### General

- Account Name.
- Provider Preset.
- Email Address.
- From Name.
- Reply-To Address.
- Notes.
- Active.

### SMTP

- SMTP Host.
- SMTP Port.
- Encryption Type.
- SMTP Username.
- SMTP Password.
- Sending Enabled.

### IMAP

- IMAP Host.
- IMAP Port.
- Encryption Type.
- IMAP Username.
- IMAP Password.
- Receiving Enabled.
- Sync Enabled.

### Defaults

- Default for Manual Email.
- Default for Transactional Email.
- Default for OTP.
- Default for Broadcast.
- Default for Incoming Sync.

### Limits and Queue

- Hourly Send Limit.
- Daily Send Limit.
- Maximum Recipients Per Message.
- Critical Email Reserve Per Hour.
- Queue Batch Size.
- Minimum Delay Between Sends.
- Maximum Concurrent Sends.
- Maximum Retry Count.

### Actions

- Save.
- Cancel.
- Test SMTP.
- Test IMAP.
- Send Test Email.
- Sync Now.

Requirements:

- Tests must run server-side.
- Password fields must never refill with actual decrypted values.
- Leaving a password field blank during edit must preserve the existing encrypted password.
- Replacing a password must rotate the encrypted value.
- Display safe validation errors.
- Never log entered credentials.

---

# 16. Email Templates Window

Provide:

- Template table.
- Search.
- Category filter.
- Active filter.
- Create.
- Edit.
- Duplicate.
- Preview.
- Version History.
- Deactivate/Delete.

Editor fields:

- Template Name.
- Template Code.
- Category.
- Subject.
- Rich HTML Body.
- Plain Text Body.
- Default Signature.
- Active.

Support placeholders such as:

```text
{{customer_name}}
{{customer_email}}
{{employee_name}}
{{supplier_name}}
{{otp}}
{{expiry_minutes}}
{{invoice_no}}
{{invoice_date}}
{{amount}}
{{company_name}}
{{branch_name}}
{{support_email}}
```

Do not replace unknown placeholders silently. Show validation errors.

Provide:

- Placeholder picker.
- Live preview.
- Mobile-width preview.
- Desktop-width preview.
- Test-data preview.
- Send test email.

Sanitise HTML and prevent unsafe scripts.

---

# 17. Email Signatures Window

Provide:

- Signature table.
- Search.
- Department filter.
- Create.
- Edit.
- Duplicate.
- Preview.
- Set Default.
- Deactivate/Delete.

Fields:

- Signature Name.
- Department.
- HTML Signature.
- Plain Text Signature.
- Default.
- Active.

Support signatures for:

- Support.
- Sales.
- Finance.
- HR.
- Marketing.
- General.

---

# 18. Email Groups Window

Provide:

- Static groups.
- Dynamic groups.
- Search.
- Member count.
- Consent count.
- Invalid count.
- Suppressed count.

Create/Edit fields:

- Group Name.
- Group Type.
- Description.
- Static or Dynamic.
- Dynamic source.
- Dynamic filters.
- Active.

Member sources:

- Manual entry.
- CSV import.
- Customers.
- Suppliers.
- Employees.
- Loyalty members.
- Branch managers.
- Future CRM sources.

CSV import must provide:

- Column mapping.
- Validation preview.
- Duplicate detection.
- Invalid-email detection.
- Consent-field mapping.
- Import summary.

---

# 19. Email Centre Window

Build a complete desktop email client using the Aqura window system.

## 19.1 Layout

Recommended three-panel layout:

1. Folder/navigation panel.
2. Message list.
3. Reading/preview pane.

The user must be able to collapse panels according to existing responsive behaviour.

## 19.2 Folders

- Inbox.
- Sent.
- Drafts.
- Spam.
- Archive.
- Trash.
- Starred.
- Unread.
- Custom folders.

Show unread counts.

## 19.3 Message List

Show:

- Sender or recipient.
- Subject.
- Preview.
- Date/time.
- Read status.
- Star.
- Attachment indicator.
- Priority.
- Account.
- Folder.
- Linked business entity.

Provide:

- Search.
- Date filter.
- Sender filter.
- Recipient filter.
- Account filter.
- Folder filter.
- Read/unread filter.
- Attachment filter.
- Priority filter.
- Linked entity filter.

## 19.4 Reading Pane

Display:

- From.
- To.
- CC.
- Reply-To.
- Date/time.
- Subject.
- Sanitised HTML.
- Plain-text fallback.
- Attachments.
- Thread history.
- Linked entity.
- Delivery information for outgoing mail.

Actions:

- Reply.
- Reply All.
- Forward.
- Mark Read/Unread.
- Star/Unstar.
- Archive.
- Move.
- Delete.
- Print if supported.
- Download attachment.
- Link to business record.
- Create support ticket in future-ready form.

## 19.5 Synchronisation

Provide:

- Sync Now.
- Last Sync.
- Sync Status.
- New-message indicator.
- Safe sync error display.

Receiving an email must not require the Email Centre window to remain open.

---

# 20. Compose Email Window

Fields:

- From Account.
- From Name.
- To.
- CC.
- BCC.
- Subject.
- Rich HTML Editor.
- Plain Text alternative.
- Attachments.
- Template.
- Signature.
- Priority.
- Schedule Date/Time.
- Request Read Receipt where supported.
- Linked business entity.
- Save Draft.
- Send.

Requirements:

- Recipient autocomplete from existing entities where permission permits.
- Validate addresses before sending.
- Warn about empty subject.
- Warn about attachments mentioned but not added where practical.
- Auto-save drafts according to database settings.
- Never send directly from the browser using SMTP credentials.
- Sending must create a backend queue item or secure send request.
- Show clear queued/sent/failed status.

---

# 21. Broadcast Email Window

This window is for controlled campaigns, not ordinary direct SMTP mass sending.

## 21.1 Campaign Setup

Fields:

- Campaign Name.
- Sending Account.
- Recipient Source.
- Email Groups.
- Customers.
- Suppliers.
- Employees.
- Loyalty Members.
- Manual Addresses.
- CSV Import.
- Template.
- Subject.
- Body.
- Signature.
- Schedule Date/Time.
- Batch Size Override.
- Delay Override.
- Tracking Options where provider supports them.

## 21.2 Mandatory Validation

Before starting:

- Count recipients.
- Remove duplicates.
- Remove invalid addresses.
- Remove suppressed addresses.
- Remove unsubscribed addresses.
- Check consent where required.
- Check account sending limits.
- Check reserved capacity for OTP and transactional messages.
- Check attachment size.
- Check missing placeholders.
- Show estimated completion time.
- Send a test email.
- Show final preview.

Require an explicit confirmation before starting.

## 21.3 Queue Behaviour

Never send thousands of emails simultaneously.

Each recipient must have an individual campaign-recipient record and queue job, unless the provider explicitly supports a safe bulk API and the architecture still records each recipient individually.

Support:

- Start.
- Pause.
- Resume.
- Cancel.
- Retry failed.
- Duplicate campaign.
- Schedule.

Broadcast emails must use a configurable dedicated account when one is assigned.

---

# 22. Email Queue Window

Show summary cards:

- Waiting.
- Processing.
- Sent Today.
- Temporary Failures.
- Permanent Failures.
- Paused.
- Cancelled.
- Critical Capacity Remaining.

Table columns:

- Queue ID.
- Type.
- Priority.
- Account.
- Recipient.
- Subject.
- Campaign.
- Scheduled Time.
- Status.
- Attempts.
- Next Retry.
- Last Error.
- Actions.

Actions:

- Pause.
- Resume.
- Retry.
- Cancel.
- View Details.

Show progress and estimated remaining time for campaigns.

Do not expose internal secrets or raw provider credentials in error details.

---

# 23. Scheduled Emails Window

Provide:

- Scheduled email table.
- Search.
- Account filter.
- Date filter.
- Status filter.
- Create.
- Edit.
- Reschedule.
- Cancel.
- Send Now where allowed.
- View message.

Statuses:

- Draft.
- Scheduled.
- Queued.
- Sent.
- Cancelled.
- Failed.

Use the user’s configured timezone and store timestamps according to the project standard.

---

# 24. Email Dashboard Window

Display database-driven cards and charts for:

- Emails Sent Today.
- Emails Received Today.
- OTP Emails Sent Today.
- Broadcast Emails Sent Today.
- Failed Today.
- Pending Queue.
- Scheduled.
- Unread.
- Active Campaigns.
- SMTP Health.
- IMAP Health.
- Last Sync.
- Storage Usage.
- Hourly Limit.
- Sent This Hour.
- Remaining Estimated Capacity.
- Critical Reserve Remaining.

Display:

- Recent Activity.
- Recent Failures.
- Current Campaign Progress.
- Account Health.
- Queue Health.
- Sync Health.
- Top Templates.
- Daily sending trend.
- Daily receiving trend.

Do not show fake delivery, opening, or click data when the provider cannot supply it.

---

# 25. Email Settings Window

All operational settings must be database-driven.

Provide configurable sections for:

- Global Sync Interval.
- Queue Processing Interval.
- Default Batch Size.
- Default Send Delay.
- Default Retry Count.
- Retry Backoff.
- Attachment Size Limit.
- Allowed Attachment Types.
- Auto-Save Draft Interval.
- Retention Period.
- Default Search Date Range.
- Tracking Defaults.
- Unsubscribe Requirements.
- Notification Settings.
- Spam Handling.
- Folder Mapping.
- Timezone.
- Log Retention.
- Maintenance Schedule.

Validate settings and prevent values that could overload the server or violate account limits.

---

# 26. AI Email Settings Window

AI features must be independently configurable.

Features:

- Email Summary.
- Translation.
- Reply Suggestion.
- Auto Categorisation.
- Sentiment Detection.
- Spam Detection.
- Priority Detection.
- Auto Draft.
- Automatic Ticket Suggestion.
- Automatic Ticket Creation.
- Auto Reply.

For every feature provide:

- Enabled.
- Provider.
- Model.
- Prompt Template.
- Language Mode.
- Confidence Threshold.
- Human Approval Required.
- Auto-Send Allowed.
- Maximum Tokens.
- Allowed Account.
- Allowed Folder.
- Allowed User Role.

Safety requirements:

- Human approval must be the default for reply generation.
- Auto-send must be disabled by default.
- Incoming email content must be treated as untrusted.
- Prevent prompt injection from causing data access, secret disclosure, or unauthorised actions.
- Do not send confidential internal information.
- Log every AI action.
- Allow users to edit generated text before sending.

---

# 27. OTP and Transactional Email API

Create a reusable internal backend interface for future modules.

Supported message types:

- Email OTP.
- Password Reset.
- Email Verification.
- Account Activation.
- Invoice Notification.
- Payment Reminder.
- Leave Approval.
- Employee Notification.
- System Alert.

Requirements:

- Select the active default account for the message purpose from the database.
- Use a template from the database.
- Validate placeholders.
- Queue the message with critical priority where appropriate.
- Respect reserved hourly capacity.
- Record the source module and source record.
- Return a safe message ID and status.
- Never return SMTP credentials.
- OTP values must not be logged in plain text.
- OTP expiry must follow existing authentication security rules.

---

# 28. Rate Limits and Capacity Management

All limits must be configurable per account.

The system must support:

- Hourly limit.
- Daily limit.
- Maximum recipients per message.
- Minimum delay.
- Batch size.
- Maximum concurrency.
- Critical reserve.
- Retry limit.

Every outgoing recipient counts against usage.

Examples that count:

- OTP.
- Password reset.
- Invoice.
- Manual email.
- Reply.
- Notification.
- Broadcast recipient.
- AI auto-reply when actually sent.

Examples that do not count until sent:

- Draft.
- AI summary.
- AI translation.
- AI reply suggestion.
- Received email.
- Saved template.

The Aqura usage meter is an internal estimate based on Aqura sends. Clearly label it as estimated when the provider does not expose a live quota API.

Prevent broadcasts from consuming the capacity reserved for critical emails.

---

# 29. Attachments and Storage

Use the existing Aqura/Supabase storage architecture.

Create a dedicated bucket or approved folder structure, following project conventions.

Requirements:

- Store metadata in `email_attachments`.
- Store files in storage.
- Use safe generated paths.
- Preserve original file name separately.
- Enforce maximum size.
- Enforce allowed types.
- Calculate checksum.
- Prevent path traversal.
- Use signed or authorised downloads.
- Support inline content IDs.
- Avoid duplicate downloads where practical.
- Scan files when an existing malware-scanning mechanism exists.
- Mark scan status.
- Do not automatically execute or render unsafe attachments.

---

# 30. Incoming Email Synchronisation Rules

The sync service must:

1. Read only active accounts with IMAP sync enabled.
2. Load encrypted credentials server-side.
3. Connect securely.
4. Discover folders.
5. Track UIDVALIDITY and the last processed UID.
6. Download only required new or changed messages.
7. Prevent duplicates.
8. Store headers, body, recipients, flags, and attachments.
9. Update local folder and read states.
10. Record a sync run.
11. Release locks.
12. Schedule retry after temporary failure.

Handle:

- Recreated folders.
- Changed UIDVALIDITY.
- Deleted remote messages.
- Moved messages.
- Duplicate Message-ID values.
- Messages without HTML.
- Messages without Message-ID.
- Large attachments.
- Invalid character sets.
- Inline images.
- Broken MIME structures.
- Network timeouts.
- Authentication failure.

Do not delete remote mail unless the user explicitly performs an authorised delete action and the configured synchronisation policy permits it.

---

# 31. Outgoing Email Rules

For every outgoing email:

1. Validate user permission or trusted system source.
2. Select the configured account from the database.
3. Validate the account is active and sending enabled.
4. Validate recipients.
5. Check suppression and unsubscribe rules.
6. Validate attachment size/type.
7. Render template and placeholders.
8. Apply signature.
9. Create message record.
10. Create recipient records.
11. Create queue item with idempotency key.
12. Enforce limits and critical reserve.
13. Load encrypted credentials server-side.
14. Send through SMTP or provider API.
15. Store provider message ID.
16. Update statuses.
17. Record attempts and logs.
18. Retry temporary failures.
19. Mark permanent failures.
20. Never expose secret values.

---

# 32. Reply, Reply All, and Forward Rules

Reply must:

- Use the correct account.
- Preserve thread headers.
- Set `In-Reply-To`.
- Set `References`.
- Quote prior content safely.
- Exclude BCC from recipient-visible headers.

Reply All must:

- Include valid original To and CC participants.
- Exclude the current sending account.
- Remove duplicate recipients.
- Exclude BCC addresses not visible to the user.

Forward must:

- Create a new message.
- Preserve forwarded content safely.
- Allow attachment selection.
- Not disclose hidden BCC information.

---

# 33. Delivery, Open, and Click Tracking

Support provider delivery events when available.

Do not claim delivery confirmation when the provider only confirms SMTP acceptance.

Provide accurate statuses:

- Queued.
- Submitted.
- Accepted by SMTP.
- Delivered, only when provider confirms.
- Opened, only when tracking is enabled and detected.
- Clicked, only when tracking is enabled and detected.
- Bounced.
- Complained.
- Failed.

Tracking must be configurable and compliant with the selected organisation’s privacy policy.

---

# 34. Unsubscribe and Marketing Safety

Broadcast campaigns must support:

- Unsubscribe link.
- Suppression list.
- Hard-bounce suppression.
- Complaint suppression.
- Manual block.
- Consent status.
- Consent source.
- Consent date.

A recipient who has unsubscribed or generated a hard bounce/complaint must not receive further marketing emails unless an authorised and legally valid re-subscription process restores consent.

Transactional emails may follow separate rules but must not be mislabelled as transactional merely to bypass marketing restrictions.

---

# 35. Reports

## 35.1 Email Logs

Filters:

- Date.
- User.
- Account.
- Event Type.
- Message.
- Campaign.
- Status.
- Source Module.

## 35.2 Delivery Reports

Show:

- Submitted.
- SMTP Accepted.
- Delivered when known.
- Bounced.
- Complained.
- Opened when known.
- Clicked when known.
- Pending.
- Failed.

## 35.3 Campaign Reports

Show:

- Campaign Name.
- Account.
- Start Time.
- End Time.
- Total.
- Queued.
- Sent.
- Delivered.
- Failed.
- Bounced.
- Opened.
- Clicked.
- Unsubscribed.
- Progress.
- Completion Time.

## 35.4 Failed Emails

Show:

- Recipient.
- Subject.
- Account.
- Failure Category.
- Safe Failure Message.
- Attempt Count.
- Next Retry.
- Permanent/Temporary.
- Retry Action.
- Cancel Action.

Never display passwords or raw secret-bearing provider responses.

---

# 36. Logging and Audit Requirements

Log:

- Account created.
- Account edited.
- Credentials changed.
- SMTP tested.
- IMAP tested.
- Manual sync started.
- Sync completed.
- Sync failed.
- Message drafted.
- Message queued.
- Message sent.
- Message failed.
- Message retried.
- Message cancelled.
- Campaign created.
- Campaign started.
- Campaign paused.
- Campaign resumed.
- Campaign cancelled.
- Template created/edited.
- Signature created/edited.
- Group created/edited.
- Settings changed.
- AI action generated.
- AI action approved.
- AI action rejected.
- Permission failure.
- Security-sensitive event.

Redact:

- SMTP password.
- IMAP password.
- API key.
- Webhook secret.
- Encryption key.
- Service-role key.
- SSH key.
- OTP.
- Sensitive tokens.

---

# 37. Security Requirements

Implement:

- TLS for SMTP and IMAP.
- Server-side credential decryption.
- AES-256-GCM or an existing approved encryption utility.
- Key versioning and credential rotation.
- Secret redaction.
- RLS.
- Server-side permission validation.
- CSRF/session protections according to current architecture.
- HTML sanitisation.
- Attachment validation.
- Rate limiting.
- Idempotency.
- Queue locking.
- Webhook signature verification.
- Safe error handling.
- Audit logs.
- Least-privilege service access.

Do not:

- Store plaintext credentials.
- Put secrets in Svelte environment variables exposed to the browser.
- Return secret columns through RPC.
- Log decrypted secrets.
- Commit secrets.
- Add SMTP passwords to migration files.
- Hardcode `support@urbanaqura.com` or any other account.
- Hardcode provider-specific connection values as the only supported path.
- Use browser-side SMTP.

---

# 38. Database-Driven Configuration Requirement

The following values must come from the database at runtime:

- Active email accounts.
- Email addresses.
- Sender names.
- Reply-to addresses.
- SMTP hosts.
- SMTP ports.
- SMTP usernames.
- SMTP encryption.
- IMAP hosts.
- IMAP ports.
- IMAP usernames.
- IMAP encryption.
- Default account by purpose.
- Account status.
- Sync status.
- Hourly limits.
- Daily limits.
- Recipient limits.
- Queue batch sizes.
- Queue delays.
- Retry limits.
- Sync intervals.
- AI feature settings.
- Template selection.
- Signature selection.
- Retention settings.
- Attachment settings.
- Broadcast settings.

Encrypted passwords and provider secrets must also be stored in the database, but decrypted only server-side using a non-hardcoded secure master key.

Changing an account or default selection in Aqura must take effect without editing code or redeploying the frontend.

---

# 39. Migration and Deployment

Use the existing project migration and SSH deployment process.

The coding agent must:

1. Create migration files.
2. Create tables.
3. Create indexes.
4. Create constraints.
5. Create triggers.
6. Create views.
7. Create RPC functions.
8. Create RLS policies.
9. Create storage bucket and policies.
10. Create Edge Functions.
11. Create scheduler jobs.
12. Create worker service when required.
13. Deploy backend components.
14. Register frontend navigation.
15. Register permissions.
16. Build the frontend.
17. Run database validation.
18. Run end-to-end tests.

Do not ask the user to copy and paste SQL manually.

Do not delete or modify existing production data unless a migration explicitly requires a safe change.

Every migration must be idempotent or safely versioned according to the existing project standard.

Provide rollback guidance for structural changes.

---

# 40. Testing Requirements

## 40.1 Unit Tests

Cover:

- Address validation.
- Template rendering.
- Placeholder validation.
- Rate calculation.
- Queue transitions.
- Retry logic.
- Duplicate prevention.
- Suppression checks.
- Permission checks.
- Credential masking.
- Thread matching.
- Campaign recipient expansion.

## 40.2 Integration Tests

Cover:

- Save account.
- Test SMTP.
- Test IMAP.
- Send test email.
- Receive test email.
- Sync folder.
- Download attachment.
- Reply.
- Reply All.
- Forward.
- Save draft.
- Schedule email.
- Process queue.
- Pause/resume campaign.
- Retry temporary failure.
- Reject permanent failure.
- Apply suppression.
- Use default account by purpose.

## 40.3 Permission Tests

Test:

- User with no Email permission.
- User with one button permission.
- User with subsection permissions.
- User with view but no create/edit/delete.
- User with queue view but no queue actions.
- User with campaign create but no start.
- Super Admin.
- Hidden subsection logic.
- Hidden main section logic.
- Direct RPC access without permission.

## 40.4 Security Tests

Test:

- Credentials absent from frontend network responses.
- Credentials absent from browser bundle.
- Credentials absent from logs.
- RLS blocks unauthorised reads.
- Secret table cannot be selected by client.
- HTML scripts are removed.
- Unsafe attachments are blocked.
- Webhook signature is required.
- Duplicate queue execution is prevented.
- Replayed send request is idempotent.
- Prompt injection cannot expose secrets or trigger unauthorised email sending.

## 40.5 End-to-End Real Mail Test

Using an account entered through the Aqura Email Accounts window:

1. Save account.
2. Test SMTP successfully.
3. Test IMAP successfully.
4. Send an email from Aqura to an external address.
5. Confirm it arrives.
6. Reply from the external address.
7. Run or wait for IMAP sync.
8. Confirm the reply appears in Aqura.
9. Reply from Aqura.
10. Confirm correct threading.
11. Send an attachment.
12. Receive an attachment.
13. Confirm logs, queue records, usage counts, and statuses.

Do not mark the module complete before this real end-to-end test passes.

---

# 41. Performance and Reliability

Implement:

- Pagination.
- Indexed queries.
- Incremental IMAP sync.
- Background processing.
- Queue locking.
- Idempotency.
- Attachment streaming where supported.
- Limited concurrency.
- Retry backoff.
- Safe timeouts.
- Connection cleanup.
- Batch processing.
- Avoid loading full message bodies in list views.
- Avoid loading all attachments until requested.
- Cache only non-sensitive metadata where appropriate.

The Email Centre must remain usable with large mailboxes.

---

# 42. Error Handling

Display user-friendly errors while logging safe technical details.

Categories:

- Invalid configuration.
- Authentication failed.
- Connection timeout.
- TLS failure.
- Provider rate limit.
- Hourly limit reached.
- Daily limit reached.
- Invalid recipient.
- Mailbox unavailable.
- Attachment too large.
- Unsupported attachment.
- Temporary provider error.
- Permanent recipient failure.
- Permission denied.
- Sync conflict.
- Duplicate request.
- Unknown failure.

Do not expose stack traces, secrets, or raw provider authentication responses to normal users.

---

# 43. Completion Report Required From the Coding Agent

After implementation, provide a concise but complete report containing:

- Files created.
- Files modified.
- Sidebar buttons added.
- Permission keys added.
- Windows created.
- Tables created.
- RPCs created.
- Triggers and indexes created.
- RLS policies created.
- Storage bucket/policies created.
- Edge Functions created.
- Scheduler jobs created.
- Worker service created, if required.
- SMTP runtime approach selected.
- IMAP runtime approach selected.
- Migration result.
- Frontend build result.
- Test results.
- Real send/receive result.
- Remaining limitations.
- Any provider-specific limitations.
- Rollback notes.

Do not merely say “completed.” Provide evidence.

---

# 44. Final Acceptance Criteria

The job is complete only when all the following are true:

- The Email main section appears in the sidebar for authorised users.
- Dashboard, Management, Operations, and Reports subsections work.
- Every required button opens the correct Aqura window.
- Main section and subsections hide correctly based on button permissions.
- All action permissions are enforced server-side.
- Email account settings are created through Aqura.
- No email setup is hardcoded.
- No password or secret reaches the frontend.
- SMTP test works.
- IMAP test works.
- Real outgoing email works.
- Real incoming email synchronisation works.
- Email Centre displays synchronised messages.
- Reply, Reply All, and Forward work.
- Attachments work.
- Drafts work.
- Templates work.
- Signatures work.
- Groups work.
- Scheduled emails work.
- Broadcast queue works.
- Pause, Resume, Retry, and Cancel work.
- Rate limits and critical reserve work.
- OTP/transactional API is ready.
- Reports show real data.
- Logs are complete and redacted.
- AI settings are configurable and disabled by default where appropriate.
- Edge Functions are created and deployed.
- A secure worker is created if the Edge runtime cannot reliably perform SMTP/IMAP.
- All migrations succeed.
- The frontend builds successfully.
- Existing modules remain functional.
- The UI follows the Aqura light theme.
- Window action buttons use the required light glassmorphism style.
- End-to-end send and receive tests pass.
- The coding agent provides the required completion report.

---

# 45. Final Instruction to the Coding Agent

Proceed autonomously after repository analysis and complete the entire Email module.

Do not stop to ask the user for technical decisions that can be resolved by inspecting the existing Aqura architecture or by choosing the safest production-ready implementation.

Ask the user only when a genuinely required external credential, provider approval, or business-policy decision cannot be inferred or configured later through the database.

The final implementation must be functional, secure, database-driven, permission-controlled, production-ready, and visually consistent with Aqura.
