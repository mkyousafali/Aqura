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
  require_task_finished boolean null default true,
  require_photo_upload boolean null default false,
  require_erp_reference boolean null default false,
  constraint quick_task_assignments_pkey primary key (id),
  constraint quick_task_assignments_quick_task_id_assigned_to_user_id_key unique (quick_task_id, assigned_to_user_id),
  constraint quick_task_assignments_assigned_to_user_id_fkey foreign KEY (assigned_to_user_id) references users (id) on delete CASCADE,
  constraint quick_task_assignments_quick_task_id_fkey foreign KEY (quick_task_id) references quick_tasks (id) on delete CASCADE,
  constraint chk_require_task_finished_not_null check ((require_task_finished is not null))
) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_task on public.quick_task_assignments using btree (quick_task_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_user on public.quick_task_assignments using btree (assigned_to_user_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_status on public.quick_task_assignments using btree (status) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_created_at on public.quick_task_assignments using btree (created_at) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_require_task_finished on public.quick_task_assignments using btree (require_task_finished) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_require_photo_upload on public.quick_task_assignments using btree (require_photo_upload) TABLESPACE pg_default
where
  (require_photo_upload = true);

create index IF not exists idx_quick_task_assignments_require_erp_reference on public.quick_task_assignments using btree (require_erp_reference) TABLESPACE pg_default
where
  (require_erp_reference = true);

create trigger trigger_copy_completion_requirements
after INSERT on quick_task_assignments for EACH row
execute FUNCTION copy_completion_requirements_to_assignment ();

create trigger trigger_create_quick_task_notification
after INSERT on quick_task_assignments for EACH row
execute FUNCTION create_quick_task_notification ();

create trigger trigger_update_quick_task_status
after
update on quick_task_assignments for EACH row
execute FUNCTION update_quick_task_status ();