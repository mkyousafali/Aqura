create table public.recurring_assignment_schedules (
  id uuid not null default gen_random_uuid (),
  assignment_id uuid not null,
  repeat_type text not null,
  repeat_interval integer not null default 1,
  repeat_on_days integer[] null,
  repeat_on_date integer null,
  repeat_on_month integer null,
  execute_time time without time zone not null default '09:00:00'::time without time zone,
  timezone text null default 'UTC'::text,
  start_date date not null,
  end_date date null,
  max_occurrences integer null,
  is_active boolean null default true,
  last_executed_at timestamp with time zone null,
  next_execution_at timestamp with time zone not null,
  executions_count integer null default 0,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  created_by text not null,
  constraint recurring_assignment_schedules_pkey primary key (id),
  constraint fk_recurring_schedules_assignment foreign KEY (assignment_id) references task_assignments (id) on delete CASCADE,
  constraint chk_repeat_interval_positive check ((repeat_interval > 0)),
  constraint chk_max_occurrences_positive check (
    (
      (max_occurrences is null)
      or (max_occurrences > 0)
    )
  ),
  constraint recurring_assignment_schedules_repeat_type_check check (
    (
      repeat_type = any (
        array[
          'daily'::text,
          'weekly'::text,
          'monthly'::text,
          'yearly'::text,
          'custom'::text
        ]
      )
    )
  ),
  constraint chk_schedule_bounds check (
    (
      (end_date is null)
      or (end_date >= start_date)
    )
  ),
  constraint chk_next_execution_after_start check (((next_execution_at)::date >= start_date))
) TABLESPACE pg_default;

create index IF not exists idx_recurring_schedules_assignment_id on public.recurring_assignment_schedules using btree (assignment_id) TABLESPACE pg_default;

create index IF not exists idx_recurring_schedules_next_execution on public.recurring_assignment_schedules using btree (next_execution_at, is_active) TABLESPACE pg_default
where
  (is_active = true);

create index IF not exists idx_recurring_schedules_active on public.recurring_assignment_schedules using btree (is_active, repeat_type) TABLESPACE pg_default;