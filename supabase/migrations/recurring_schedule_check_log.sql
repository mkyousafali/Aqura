create table public.recurring_schedule_check_log (
  id serial not null,
  check_date date not null default CURRENT_DATE,
  schedules_checked integer null default 0,
  notifications_sent integer null default 0,
  created_at timestamp with time zone null default now(),
  constraint recurring_schedule_check_log_pkey primary key (id),
  constraint recurring_schedule_check_log_check_date_key unique (check_date)
) TABLESPACE pg_default;