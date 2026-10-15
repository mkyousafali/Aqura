# Internal WhatsApp — Architecture and Extension Guide

## Purpose

Aqura has two deliberately separate WhatsApp environments:

1. **Customer WhatsApp** — the existing customer-facing account and all existing customer workflows.
2. **Internal WhatsApp** — the employee-only account used for internal communication, attendance notifications, employee assistance, and protected operational data.

The internal account must never fall back to, merge with, or modify customer WhatsApp behavior. Any new feature must preserve this separation in database queries, credentials, conversations, settings, templates, automation, AI configuration, permissions, unread counts, and UI windows.

Only one customer account and one internal account are supported. The internal account is identified through the singleton row in `public.wa_internal_account`.

## Non-negotiable security rules

- Internal WhatsApp accepts messages only from an active, unlocked Aqura user whose normalized WhatsApp number matches `hr_employee_master.whatsapp_number` and whose employment status is not resigned.
- Unknown or unauthorized numbers receive the bilingual access-denied message and are blocked through Meta.
- Locking or deactivating a user blocks their number from Internal WhatsApp. Reactivating/unlocking the user removes that block.
- An employee may remain active without Internal WhatsApp access when no WhatsApp number is saved.
- Employee WhatsApp numbers must be unique after normalization.
- Protected information must be read from Aqura/ERP data. The AI must never invent attendance, shifts, leave, sales, permissions, or other operational facts.
- Permissions must be checked again when executing an action. Showing a button is not sufficient security because a WhatsApp interactive-reply ID can be forged.
- Never expose another employee's data. Resolve the requesting employee from the inbound phone number.
- Never put access tokens, service-role keys, Meta credentials, PINs, or production secrets in source code or this document.

## Account and database model

Important tables and functions:

- `wa_accounts` — credentials and metadata for WhatsApp accounts.
- `wa_internal_account` — singleton link to the internal `wa_accounts` row.
- `wa_settings` — settings scoped by `wa_account_id`.
- `wa_ai_config` — AI configuration scoped by `wa_account_id`.
- `wa_conversations` — conversations scoped by `wa_account_id` and phone.
- `wa_messages` — inbound/outbound live-chat history.
- `wa_internal_security_audit` — denied/blocked internal traffic audit.
- `wa_internal_assistant_state` — short-lived state for multi-step deterministic assistant flows.
- `get_internal_whatsapp_account()` — returns the internal account.
- `is_internal_whatsapp_account(uuid)` — identifies internal traffic.
- `is_internal_whatsapp_authorized_phone(text)` — validates an employee phone.
- `get_internal_whatsapp_contacts(...)` — employee-only contacts for internal UI.

Phone matching must normalize punctuation, spaces, international prefixes, and Saudi local mobile numbers. Do not compare raw formatted phone strings.

## Main implementation files

### Backend

- `database/edge-functions/whatsapp-webhook/index.ts`
  - Receives both WhatsApp accounts.
  - Resolves the account from Meta's `phone_number_id`.
  - Enforces internal authorization before creating a conversation.
  - Stores inbound messages.
  - Routes deterministic employee assistant features before general auto-reply/AI.
  - Sends replies through credentials belonging to the conversation's account.
  - Stores outbound replies in `wa_messages` so Live Chat updates in realtime.
- `database/edge-functions/whatsapp-manage/index.ts`
  - Sends/broadcasts WhatsApp messages and writes them into Live Chat.
- `database/edge-functions/send-whatsapp/index.ts`
  - Routes employee OTPs and credentials through Internal WhatsApp.
  - Customer authentication messages remain on Customer WhatsApp.
- `database/edge-functions/attendance-no-show/index.ts`
  - Sends real attendance alerts through the internal account.
  - Saves successful notifications in the recipient's internal Live Chat conversation.
- `database/edge-functions/attendance-notification-test/index.ts`
  - Sends test notifications through the internal account and stores them in Live Chat.
- `database/edge-functions/analyze-attendance/index.ts`
  - Authoritative attendance/shift analysis used by the employee shift assistant.
- `database/edge-functions/internal-whatsapp-access/index.ts`
  - Synchronizes employee access and Meta block/unblock behavior.

### Frontend

- `frontend/src/lib/whatsapp/accountScope.ts` — resolves `customer` or `internal` account scope.
- `frontend/src/lib/components/desktop-interface/common/Sidebar.svelte` — permission-gated Internal WhatsApp section.
- `frontend/src/lib/components/desktop-interface/common/Taskbar.svelte` — permission-gated internal Live Chat shortcut and unread badge.
- `frontend/src/lib/components/desktop-interface/whatsapp/WALiveChat.svelte` — shared Live Chat with account scope, employee names, chronological history, and realtime updates.
- `frontend/src/lib/components/desktop-interface/whatsapp/InternalWAAccounts.svelte` — internal account view.
- `frontend/src/lib/components/desktop-interface/whatsapp/InternalWAContacts.svelte` — employee contacts.
- `frontend/src/lib/components/desktop-interface/whatsapp/AIReply.svelte` — account-scoped AI settings with an internal-purpose layout.
- `frontend/src/lib/stores/waUnreadCount.ts` — separate customer and internal unread counters.
- `frontend/static/icons/internal-whatsapp-aqura.png` — approved Aqura-colored Internal WhatsApp icon.

## UI permissions

Master Admins automatically pass all button checks. Other users see only explicitly granted buttons.

Internal WhatsApp permission codes:

- `INTERNAL_WA_DASHBOARD`
- `INTERNAL_WA_LIVE_CHAT`
- `INTERNAL_WA_CONTACTS`
- `INTERNAL_WA_BROADCASTS`
- `INTERNAL_WA_TEMPLATES`
- `INTERNAL_WA_AUTO_REPLY`
- `INTERNAL_WA_AI_BOT`
- `INTERNAL_WA_CATALOG`
- `INTERNAL_WA_ACCOUNTS`
- `INTERNAL_WA_SETTINGS`

The sidebar section is hidden when the user is not a Master Admin and has none of these permissions. Each submenu item is checked separately. The taskbar icon requires `INTERNAL_WA_LIVE_CHAT` unless the user is a Master Admin.

These UI checks control visibility only. Backend features that expose protected data require their own authorization checks.

## Existing employee assistant features

### Aqura Companion / مرافق أكورا

Internal AI settings are separate from customer AI settings. The configured internal assistant name is:

- English: `Aqura Companion`
- Arabic: `مرافق أكورا`

The internal AI configuration includes employee-support knowledge, internal escalation rules, privacy boundaries, and internal training examples. Customer links, offers, services, and customer complaint configuration are hidden from the internal AI settings screen.

### Shift and attendance self-service

When an employee asks about their shift, the webhook sends three WhatsApp quick replies:

- Today
- Tomorrow
- Another date

The answer is generated from `analyze-attendance`, not from AI. It can include:

- Scheduled shift start/end
- Check-in/check-out
- Attendance status
- Late minutes
- Weekly or specific day off
- Approved/pending leave
- Official holiday

Only the requesting employee's record is returned.

### Assigned-employee arrival lookup

An enabled attendance-notification recipient can ask whether one monitored employee arrived today.

- Access is taken from `attendance_notification_recipients`; being a Master Admin alone does not grant this lookup.
- Branch-scoped recipients can search only monitored employees in their configured branches. Recipients with `all_branches` can search all monitored employees.
- Search uses Arabic and English employee names, tolerates minor typing errors, and never searches by employee ID.
- Ambiguous results are returned as an interactive employee list (up to 10 per page), with a Next action for additional results.
- Selection state expires after 10 minutes, and authorization/branch scope is checked again when a selection is executed.
- Before answering, the webhook runs `process-fingerprints` and `analyze-attendance` for today's Riyadh date.
- Every shift is reported separately with scheduled time, arrival time, on-time/late status, and late minutes calculated from the scheduled start.
- A future shift says it has not started; a started shift without a check-in says the employee has not arrived yet.
- Approved leave, weekly day off, official holiday, and no-shift cases are reported explicitly.
- Replies use only the detected question language and are generated from authoritative attendance data, not by the language model.

### Sales report self-service

When an employee asks for a sales report, the webhook offers:

- Today
- Yesterday
- Specific Date

Rules:

- A Master Admin is automatically authorized and receives every active ERP branch separately plus the available total.
- A normal employee requires an enabled `SALES_REPORT` button permission and receives only their assigned branch.
- The branch is taken from the user's branch, with Employee Master current branch as the fallback.
- The report returns **net sales only**, calculated exactly like the Sales Report window: sales invoices (`SI`) minus sales returns (`SR`).
- Specific dates accept common formats and Arabic/Persian digits, then require confirmation.
- Future dates are rejected.
- If a branch is offline, other branches are still reported and the failed branch is marked unavailable.
- Permission is rechecked immediately before the ERP request.
- Responses use the language of the employee's request.

## Live Chat behavior

- Internal and customer conversations are separated by `wa_account_id`.
- Conversation cards use the authoritative Employee Master name, not a WhatsApp profile name.
- Historical attendance recipients whose phone later changed are resolved through the original notification recipient user ID.
- Attendance alerts, test alerts, assistant replies, broadcasts, and operator messages must all insert a corresponding `wa_messages` row after a successful Meta send.
- Update `wa_conversations.last_message_at` and `last_message_preview` after saving an outbound message.
- Historical records retain their original `created_at` time.
- `WALiveChat.svelte` sorts initial, paginated, realtime-inserted, and updated messages chronologically.
- Internal inbound bubbles display the employee name. Customer chat continues to display the customer label.

## Templates

Both phone numbers belong to the same Meta WhatsApp Business Account, so approved Meta templates are shared at the WABA level. Employee templates do not need to be duplicated merely because messages are sent from the internal phone number.

The sender account still matters: employee templates and notifications must use the internal account's phone-number ID and access token. Customer OTPs and customer workflows must continue using the customer/default account.

## How to add a new internal assistant feature

Use this pattern for operational features such as payroll summaries, leave balances, tasks, or approval status:

1. **Define the intent and authorization rule.** Choose an existing button permission or add a narrowly scoped new permission code.
2. **Route only internal traffic.** Add the deterministic handler inside the `isInternalAccount` path in `whatsapp-webhook/index.ts`, before general auto-reply/AI.
3. **Resolve the requester from the phone.** Use the normalized phone to find `hr_employee_master`, its linked active/unlocked user, and the required branch/user context.
4. **Check authorization before showing sensitive options.** Return a clear same-language denial when unauthorized.
5. **Use quick replies for a small fixed choice.** WhatsApp supports a maximum of three reply buttons per button message.
6. **Use `wa_internal_assistant_state` for multi-step input.** Store a narrow `pending_action`, minimal JSON context, and timestamp. Reject stale state and clear it after completion/cancellation.
7. **Validate all user input.** Normalize dates, identifiers, and numbers. Reject future/out-of-scope values when applicable.
8. **Recheck authorization at execution time.** Never trust only the previous menu or stored state.
9. **Read authoritative data.** Call the relevant edge function, RPC, or secured ERP bridge. Never ask the AI model to calculate or invent business facts.
10. **Apply scope.** Regular users receive only their own/assigned-branch data. Define an explicit Master Admin expansion if required.
11. **Send through `sendWhatsAppMessage`.** It selects credentials from the conversation account and records the outbound message in Live Chat.
12. **Return before general AI handling.** A handled deterministic request must not also receive an AI response.
13. **Keep customer behavior untouched.** Do not change default-account fallbacks or customer UI/workflows to support an internal feature.
14. **Support both Arabic and English.** Detect the request language and keep all prompts, errors, buttons, and results consistent.

## Adding an Internal WhatsApp UI module

1. Create or reuse a component that accepts `accountScope: 'internal'`.
2. Add a unique `INTERNAL_WA_*` button code to the access-control catalog.
3. Add that code to `SUBSECTION_CODES.InternalWhatsApp` in `Sidebar.svelte`.
4. Gate the submenu button with `isButtonAllowed(code)`.
5. Pass `accountScope: 'internal'` when opening shared WhatsApp components.
6. Query records by the resolved internal `wa_account_id`; never rely on `is_default`.
7. Add a taskbar shortcut only when it materially helps daily work, and gate it with the matching permission.
8. Use the approved icon and Aqura desktop window styling.

## Relevant migrations

- `20261015_internal_whatsapp.sql` — core internal account, security, contacts, permissions, and access functions.
- `20261015_internal_whatsapp_retry.sql` — follow-up internal setup corrections.
- `20261015_internal_whatsapp_webhook_default.sql` — guarantees the internal webhook remains active.
- `20261015_scope_whatsapp_ai_config.sql` — separates AI configuration by WhatsApp account.
- `20261015_enable_internal_ai_companion.sql` — enables/configures Aqura Companion and its internal training data.
- `20261015_backfill_attendance_whatsapp_live_chat.sql` — imports historical attendance notifications into Internal Live Chat.
- `20261015_refresh_internal_whatsapp_employee_names.sql` — refreshes cards from Employee Master names.
- `20261015_fix_historical_internal_conversation_names.sql` — resolves historical phone/name changes through notification recipient history.
- `20261015_internal_whatsapp_assistant_state.sql` — state storage for multi-step internal assistant workflows.

## Deployment guidance

- Database changes belong in a new idempotent migration under `database/migrations/`.
- Edge-function changes belong under `database/edge-functions/<function-name>/index.ts` and must be deployed to the matching production function.
- Frontend changes are deployed only through the standard process documented in `deployment/AGENTS.md` and `deployment/README.md`.
- Do not manually upload frontend files or bypass the standard atomic frontend deployment.
- Do not deploy unrelated functions, migrations, or frontend changes.
- After deployment, verify account isolation, permission denial, correct branch/user scope, same-language replies, Live Chat persistence, and customer WhatsApp regression safety.

## Review checklist

Before considering a new Internal WhatsApp feature complete, confirm:

- [ ] It runs only on the internal account.
- [ ] Unauthorized, locked, inactive, external, and resigned users cannot use it.
- [ ] The required feature permission is enforced on the server.
- [ ] Master Admin behavior is explicitly defined.
- [ ] Employee and branch scope cannot be changed through user input.
- [ ] Operational facts come from authoritative Aqura/ERP data.
- [ ] Arabic and English responses work.
- [ ] Multi-step state expires or is safely ignored when stale.
- [ ] Successful outbound messages appear in Internal Live Chat.
- [ ] Employee Master names appear on conversation cards.
- [ ] Messages remain chronologically ordered.
- [ ] The customer WhatsApp account and workflows are unchanged.
- [ ] No credentials or secrets were committed.

