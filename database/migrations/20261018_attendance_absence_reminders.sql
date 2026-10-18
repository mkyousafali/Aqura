begin;

-- Server-only delivery ledger. One reminder per employee/absence date, even
-- across multiple dashboard windows or concurrent requests.
create table if not exists public.attendance_absence_reminders (
  id uuid primary key default gen_random_uuid(),
  employee_id text not null references public.hr_employee_master(id) on delete restrict,
  absence_date date not null,
  requested_by uuid not null references public.users(id) on delete restrict,
  template_language text not null check (template_language in ('en', 'ar')),
  status text not null default 'sending' check (status in ('sending', 'sent', 'failed', 'unknown')),
  whatsapp_message_id text,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  unique (employee_id, absence_date)
);

alter table public.attendance_absence_reminders enable row level security;
revoke all on public.attendance_absence_reminders from public, anon, authenticated;
grant select, insert, update on public.attendance_absence_reminders to service_role;

notify pgrst, 'reload schema';

commit;
