create table public.task_reminder_logs (
  id uuid not null default gen_random_uuid (),
  task_assignment_id uuid null,
  quick_task_assignment_id uuid null,
  task_title text not null,
  assigned_to_user_id uuid null,
  deadline timestamp with time zone not null,
  hours_overdue numeric null,
  reminder_sent_at timestamp with time zone null default now(),
  notification_id uuid null,
  status text null default 'sent'::text,
  created_at timestamp with time zone null default now(),
  constraint task_reminder_logs_pkey primary key (id),
  constraint task_reminder_logs_assigned_to_user_id_fkey foreign KEY (assigned_to_user_id) references users (id),
  constraint task_reminder_logs_notification_id_fkey foreign KEY (notification_id) references notifications (id),
  constraint task_reminder_logs_quick_task_assignment_id_fkey foreign KEY (quick_task_assignment_id) references quick_task_assignments (id) on delete CASCADE,
  constraint task_reminder_logs_task_assignment_id_fkey foreign KEY (task_assignment_id) references task_assignments (id) on delete CASCADE,
  constraint check_single_assignment check (
    (
      (
        (task_assignment_id is not null)
        and (quick_task_assignment_id is null)
      )
      or (
        (task_assignment_id is null)
        and (quick_task_assignment_id is not null)
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_task_reminder_logs_task_assignment on public.task_reminder_logs using btree (task_assignment_id) TABLESPACE pg_default
where
  (task_assignment_id is not null);

create index IF not exists idx_task_reminder_logs_quick_task on public.task_reminder_logs using btree (quick_task_assignment_id) TABLESPACE pg_default
where
  (quick_task_assignment_id is not null);

create index IF not exists idx_task_reminder_logs_user on public.task_reminder_logs using btree (assigned_to_user_id) TABLESPACE pg_default;

create index IF not exists idx_task_reminder_logs_sent_at on public.task_reminder_logs using btree (reminder_sent_at) TABLESPACE pg_default;

create index IF not exists idx_task_reminder_logs_status on public.task_reminder_logs using btree (status) TABLESPACE pg_default;