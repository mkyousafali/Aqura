create table public.quick_tasks (
  id uuid not null default gen_random_uuid (),
  title character varying(255) not null,
  description text null,
  price_tag character varying(50) null,
  issue_type character varying(100) not null,
  priority character varying(50) not null,
  assigned_by uuid not null,
  assigned_to_branch_id bigint null,
  created_at timestamp with time zone null default now(),
  deadline_datetime timestamp with time zone null default (now() + '24:00:00'::interval),
  completed_at timestamp with time zone null,
  status character varying(50) null default 'pending'::character varying,
  created_from character varying(50) null default 'quick_task'::character varying,
  updated_at timestamp with time zone null default now(),
  require_task_finished boolean null default true,
  require_photo_upload boolean null default false,
  require_erp_reference boolean null default false,
  constraint quick_tasks_pkey primary key (id),
  constraint quick_tasks_assigned_by_fkey foreign KEY (assigned_by) references users (id) on delete CASCADE,
  constraint quick_tasks_assigned_to_branch_id_fkey foreign KEY (assigned_to_branch_id) references branches (id) on delete set null,
  constraint chk_require_task_finished_not_null check ((require_task_finished is not null))
) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_assigned_by on public.quick_tasks using btree (assigned_by) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_branch on public.quick_tasks using btree (assigned_to_branch_id) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_status on public.quick_tasks using btree (status) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_deadline on public.quick_tasks using btree (deadline_datetime) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_created_at on public.quick_tasks using btree (created_at) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_issue_type on public.quick_tasks using btree (issue_type) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_priority on public.quick_tasks using btree (priority) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_require_photo_upload on public.quick_tasks using btree (require_photo_upload) TABLESPACE pg_default
where
  (require_photo_upload = true);

create index IF not exists idx_quick_tasks_require_erp_reference on public.quick_tasks using btree (require_erp_reference) TABLESPACE pg_default
where
  (require_erp_reference = true);