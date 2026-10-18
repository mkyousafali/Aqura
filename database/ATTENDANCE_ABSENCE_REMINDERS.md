# Manual absence leave-request reminders

The Fingerprint Dashboard's **Ask why** button sends the employee a leave-request
reminder through the internal WhatsApp account. It does not submit leave, change
attendance, decide eligibility for paid leave, or modify payroll.

## Activation

1. Apply only `migrations/20261018_attendance_absence_reminders.sql`.
2. Deploy the web application through `deployment/push-and-deploy.cmd` from the
   repository root. There is no new or changed edge function to deploy.
3. Meta must approve `aqura_absence_leave_request` in the recipient's language.
   Both language versions were submitted on 18 October 2026. Approval is checked
   live for every send; creating these templates does not itself send messages.

The server endpoint is `/api/attendance-absence-reminder`. Only a signed-in
desktop Master Admin or a user with enabled `FINGERPRINT_DASHBOARD` permission
can call it. The request contains only `employeeId` and an ISO absence `date`.
Recipient phone, language, account, template, and body are resolved server-side.

## Rules

- Past days only; any changed attendance, existing leave application, or
  historical non-fingerprint status prevents sending.
- Missing attendance analysis remains an absence, matching the dashboard's
  existing rule. This feature does not change that calculation.
- The recipient must have an active, unlocked account and be authorized by the
  existing internal WhatsApp phone policy. No customer-account fallback exists.
- `users.default_language` selects exactly `en` or `ar`. An unset preference
  produces a clear error instead of sending both languages or guessing.
- Meta template body variables: `{{1}}` employee name, `{{2}}` absence date
  (`DD-MM-YYYY`, consistent with Internal WhatsApp dates). No links or buttons.
- One accepted reminder per employee/date. The server-only ledger has RLS and
  a unique key to prevent concurrent or repeated sends.
- A definite Meta rejection can be retried by pressing the button again.
  `sending` and `unknown` records are not retried automatically: investigate
  provider history first to avoid sending the same employee a duplicate.
- Successful sends are saved in internal `wa_messages` and the WhatsApp log.
  A chat-log failure is shown separately and never triggers a resend.

Local regression cases are in `absenceReminder.test.ts` and the endpoint's
`server.test.ts`. They use mocks; no employee deliveries are needed.
