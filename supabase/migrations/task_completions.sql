create table public.task_completions (
  id uuid not null default gen_random_uuid (),
  task_id uuid not null,
  assignment_id uuid not null,
  completed_by text not null,
  completed_by_name text null,
  completed_by_branch_id uuid null,
  task_finished_completed boolean null default false,
  photo_uploaded_completed boolean null default false,
  erp_reference_completed boolean null default false,
  erp_reference_number text null,
  completion_notes text null,
  verified_by text null,
  verified_at timestamp with time zone null,
  verification_notes text null,
  completed_at timestamp with time zone null default now(),
  created_at timestamp with time zone null default now(),
  completion_photo_url text null,
  constraint task_completions_pkey primary key (id),
  constraint task_completions_assignment_id_fkey foreign KEY (assignment_id) references task_assignments (id) on delete CASCADE,
  constraint task_completions_task_id_fkey foreign KEY (task_id) references tasks (id) on delete CASCADE,
  constraint chk_photo_url_consistency check (
    (
      (photo_uploaded_completed = false)
      or (completion_photo_url is not null)
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_task_completions_task_id on public.task_completions using btree (task_id) TABLESPACE pg_default;

create index IF not exists idx_task_completions_assignment_id on public.task_completions using btree (assignment_id) TABLESPACE pg_default;

create index IF not exists idx_task_completions_completed_by on public.task_completions using btree (completed_by) TABLESPACE pg_default;

create index IF not exists idx_task_completions_completed_by_branch_id on public.task_completions using btree (completed_by_branch_id) TABLESPACE pg_default;

create index IF not exists idx_task_completions_task_finished on public.task_completions using btree (task_finished_completed) TABLESPACE pg_default;

create index IF not exists idx_task_completions_photo_uploaded on public.task_completions using btree (photo_uploaded_completed) TABLESPACE pg_default;

create index IF not exists idx_task_completions_erp_reference on public.task_completions using btree (erp_reference_completed) TABLESPACE pg_default;

create index IF not exists idx_task_completions_completed_at on public.task_completions using btree (completed_at desc) TABLESPACE pg_default;

create index IF not exists idx_task_completions_photo_url on public.task_completions using btree (completion_photo_url) TABLESPACE pg_default
where
  (completion_photo_url is not null);

create trigger trigger_sync_erp_on_completion
after INSERT
or
update on task_completions for EACH row
execute FUNCTION trigger_sync_erp_reference_on_task_completion ();