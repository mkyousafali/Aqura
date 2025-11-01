create table public.task_assignments (
  id uuid not null default gen_random_uuid (),
  task_id uuid not null,
  assignment_type text not null,
  assigned_to_user_id uuid null,
  assigned_to_branch_id bigint null,
  assigned_by uuid not null,
  assigned_by_name text null,
  assigned_at timestamp with time zone null default now(),
  status text null default 'assigned'::text,
  started_at timestamp with time zone null,
  completed_at timestamp with time zone null,
  schedule_date date null,
  schedule_time time without time zone null,
  deadline_date date null,
  deadline_time time without time zone null,
  deadline_datetime timestamp with time zone null,
  is_reassignable boolean null default true,
  is_recurring boolean null default false,
  recurring_pattern jsonb null,
  notes text null,
  priority_override text null,
  require_task_finished boolean null default true,
  require_photo_upload boolean null default false,
  require_erp_reference boolean null default false,
  reassigned_from uuid null,
  reassignment_reason text null,
  reassigned_at timestamp with time zone null,
  constraint task_assignments_pkey primary key (id),
  constraint task_assignments_task_id_assignment_type_assigned_to_user_i_key unique (
    task_id,
    assignment_type,
    assigned_to_user_id,
    assigned_to_branch_id
  ),
  constraint task_assignments_assigned_by_fkey foreign KEY (assigned_by) references users (id) on delete set null,
  constraint task_assignments_assigned_to_branch_id_fkey foreign KEY (assigned_to_branch_id) references branches (id) on delete set null,
  constraint task_assignments_assigned_to_user_id_fkey foreign KEY (assigned_to_user_id) references users (id) on delete set null,
  constraint task_assignments_task_id_fkey foreign KEY (task_id) references tasks (id) on delete CASCADE,
  constraint fk_task_assignments_reassigned_from foreign KEY (reassigned_from) references task_assignments (id) on delete set null,
  constraint chk_schedule_consistency check (
    (
      (
        (schedule_date is null)
        and (schedule_time is null)
      )
      or (schedule_date is not null)
    )
  ),
  constraint chk_priority_override_valid check (
    (
      (priority_override is null)
      or (
        priority_override = any (
          array[
            'low'::text,
            'medium'::text,
            'high'::text,
            'urgent'::text
          ]
        )
      )
    )
  ),
  constraint chk_deadline_consistency check (
    (
      (
        (deadline_date is null)
        and (deadline_time is null)
      )
      or (deadline_date is not null)
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_task_id on public.task_assignments using btree (task_id) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_assignment_type on public.task_assignments using btree (assignment_type) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_status on public.task_assignments using btree (status) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_deadline_datetime on public.task_assignments using btree (deadline_datetime) TABLESPACE pg_default
where
  (deadline_datetime is not null);

create index IF not exists idx_task_assignments_schedule_date on public.task_assignments using btree (schedule_date) TABLESPACE pg_default
where
  (schedule_date is not null);

create index IF not exists idx_task_assignments_recurring on public.task_assignments using btree (is_recurring, status) TABLESPACE pg_default
where
  (is_recurring = true);

create index IF not exists idx_task_assignments_reassignable on public.task_assignments using btree (is_reassignable, status) TABLESPACE pg_default
where
  (is_reassignable = true);

create index IF not exists idx_task_assignments_overdue on public.task_assignments using btree (deadline_datetime, status) TABLESPACE pg_default
where
  (
    (deadline_datetime is not null)
    and (
      status <> all (array['completed'::text, 'cancelled'::text])
    )
  );

create index IF not exists idx_task_assignments_assigned_to_branch_id on public.task_assignments using btree (assigned_to_branch_id) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_assigned_by on public.task_assignments using btree (assigned_by) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_assigned_to_user_id on public.task_assignments using btree (assigned_to_user_id) TABLESPACE pg_default;

create trigger cleanup_assignment_notifications_trigger
after DELETE on task_assignments for EACH row
execute FUNCTION trigger_cleanup_assignment_notifications ();

create trigger trigger_update_deadline_datetime BEFORE INSERT
or
update OF deadline_date,
deadline_time on task_assignments for EACH row
execute FUNCTION update_deadline_datetime ();