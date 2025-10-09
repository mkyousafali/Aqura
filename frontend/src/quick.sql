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
  constraint quick_tasks_pkey primary key (id),
  constraint quick_tasks_assigned_by_fkey foreign KEY (assigned_by) references users (id) on delete CASCADE,
  constraint quick_tasks_assigned_to_branch_id_fkey foreign KEY (assigned_to_branch_id) references branches (id) on delete set null
) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_assigned_by on public.quick_tasks using btree (assigned_by) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_branch on public.quick_tasks using btree (assigned_to_branch_id) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_status on public.quick_tasks using btree (status) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_deadline on public.quick_tasks using btree (deadline_datetime) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_created_at on public.quick_tasks using btree (created_at) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_issue_type on public.quick_tasks using btree (issue_type) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_priority on public.quick_tasks using btree (priority) TABLESPACE pg_default;

create table public.quick_task_assignments (
  id uuid not null default gen_random_uuid (),
  quick_task_id uuid not null,
  assigned_to_user_id uuid not null,
  status character varying(50) null default 'pending'::character varying,
  accepted_at timestamp with time zone null,
  started_at timestamp with time zone null,
  completed_at timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint quick_task_assignments_pkey primary key (id),
  constraint quick_task_assignments_quick_task_id_assigned_to_user_id_key unique (quick_task_id, assigned_to_user_id),
  constraint quick_task_assignments_assigned_to_user_id_fkey foreign KEY (assigned_to_user_id) references users (id) on delete CASCADE,
  constraint quick_task_assignments_quick_task_id_fkey foreign KEY (quick_task_id) references quick_tasks (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_task on public.quick_task_assignments using btree (quick_task_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_user on public.quick_task_assignments using btree (assigned_to_user_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_status on public.quick_task_assignments using btree (status) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_created_at on public.quick_task_assignments using btree (created_at) TABLESPACE pg_default;

create trigger trigger_create_quick_task_notification
after INSERT on quick_task_assignments for EACH row
execute FUNCTION create_quick_task_notification ();

create trigger trigger_update_quick_task_status
after
update on quick_task_assignments for EACH row
execute FUNCTION update_quick_task_status ();

create table public.quick_task_assignments (
  id uuid not null default gen_random_uuid (),
  quick_task_id uuid not null,
  assigned_to_user_id uuid not null,
  status character varying(50) null default 'pending'::character varying,
  accepted_at timestamp with time zone null,
  started_at timestamp with time zone null,
  completed_at timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint quick_task_assignments_pkey primary key (id),
  constraint quick_task_assignments_quick_task_id_assigned_to_user_id_key unique (quick_task_id, assigned_to_user_id),
  constraint quick_task_assignments_assigned_to_user_id_fkey foreign KEY (assigned_to_user_id) references users (id) on delete CASCADE,
  constraint quick_task_assignments_quick_task_id_fkey foreign KEY (quick_task_id) references quick_tasks (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_task on public.quick_task_assignments using btree (quick_task_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_user on public.quick_task_assignments using btree (assigned_to_user_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_status on public.quick_task_assignments using btree (status) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_created_at on public.quick_task_assignments using btree (created_at) TABLESPACE pg_default;

create trigger trigger_create_quick_task_notification
after INSERT on quick_task_assignments for EACH row
execute FUNCTION create_quick_task_notification ();

create trigger trigger_update_quick_task_status
after
update on quick_task_assignments for EACH row
execute FUNCTION update_quick_task_status ();

create table public.quick_task_files (
  id uuid not null default gen_random_uuid (),
  quick_task_id uuid not null,
  file_name character varying(255) not null,
  file_type character varying(100) null,
  file_size integer null,
  mime_type character varying(100) null,
  storage_path text not null,
  storage_bucket character varying(100) null default 'quick-task-files'::character varying,
  uploaded_by uuid null,
  uploaded_at timestamp with time zone null default now(),
  constraint quick_task_files_pkey primary key (id),
  constraint quick_task_files_quick_task_id_fkey foreign KEY (quick_task_id) references quick_tasks (id) on delete CASCADE,
  constraint quick_task_files_uploaded_by_fkey foreign KEY (uploaded_by) references users (id) on delete set null
) TABLESPACE pg_default;

create index IF not exists idx_quick_task_files_task on public.quick_task_files using btree (quick_task_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_files_uploaded_by on public.quick_task_files using btree (uploaded_by) TABLESPACE pg_default;

create table public.quick_task_user_preferences (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  default_branch_id bigint null,
  default_price_tag character varying(50) null,
  default_issue_type character varying(100) null,
  default_priority character varying(50) null,
  selected_user_ids uuid[] null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint quick_task_user_preferences_pkey primary key (id),
  constraint quick_task_user_preferences_user_id_key unique (user_id),
  constraint quick_task_user_preferences_default_branch_id_fkey foreign KEY (default_branch_id) references branches (id) on delete set null,
  constraint quick_task_user_preferences_user_id_fkey foreign KEY (user_id) references users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_quick_task_user_preferences_user on public.quick_task_user_preferences using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_user_preferences_branch on public.quick_task_user_preferences using btree (default_branch_id) TABLESPACE pg_default;