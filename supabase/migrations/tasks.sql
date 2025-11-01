create table public.tasks (
  id uuid not null default gen_random_uuid (),
  title text not null,
  description text null,
  require_task_finished boolean null default false,
  require_photo_upload boolean null default false,
  require_erp_reference boolean null default false,
  can_escalate boolean null default false,
  can_reassign boolean null default false,
  created_by text not null,
  created_by_name text null,
  created_by_role text null,
  status text null default 'draft'::text,
  priority text null default 'medium'::text,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  deleted_at timestamp with time zone null,
  due_date date null,
  due_time time without time zone null,
  due_datetime timestamp with time zone null,
  search_vector tsvector GENERATED ALWAYS as (
    to_tsvector(
      'english'::regconfig,
      (
        (title || ' '::text) || COALESCE(description, ''::text)
      )
    )
  ) STORED null,
  constraint tasks_pkey primary key (id),
  constraint tasks_priority_check check (
    (
      priority = any (array['low'::text, 'medium'::text, 'high'::text])
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_tasks_created_by on public.tasks using btree (created_by) TABLESPACE pg_default;

create index IF not exists idx_tasks_status on public.tasks using btree (status) TABLESPACE pg_default;

create index IF not exists idx_tasks_created_at on public.tasks using btree (created_at desc) TABLESPACE pg_default;

create index IF not exists idx_tasks_deleted_at on public.tasks using btree (deleted_at) TABLESPACE pg_default;

create index IF not exists idx_tasks_search_vector on public.tasks using gin (search_vector) TABLESPACE pg_default;

create index IF not exists idx_tasks_due_date on public.tasks using btree (due_date) TABLESPACE pg_default
where
  (due_date is not null);

create trigger cleanup_task_notifications_trigger
after DELETE on tasks for EACH row
execute FUNCTION trigger_cleanup_task_notifications ();