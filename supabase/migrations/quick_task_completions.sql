create table public.quick_task_completions (
  id uuid not null default gen_random_uuid (),
  quick_task_id uuid not null,
  assignment_id uuid not null,
  completed_by_user_id uuid not null,
  completion_notes text null,
  photo_path text null,
  erp_reference character varying(255) null,
  completion_status character varying(50) not null default 'submitted'::character varying,
  verified_by_user_id uuid null,
  verified_at timestamp with time zone null,
  verification_notes text null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint quick_task_completions_pkey primary key (id),
  constraint quick_task_completions_assignment_unique unique (assignment_id),
  constraint quick_task_completions_completed_by_user_id_fkey foreign KEY (completed_by_user_id) references users (id) on delete CASCADE,
  constraint quick_task_completions_verified_by_user_id_fkey foreign KEY (verified_by_user_id) references users (id) on delete set null,
  constraint quick_task_completions_assignment_id_fkey foreign KEY (assignment_id) references quick_task_assignments (id) on delete CASCADE,
  constraint quick_task_completions_quick_task_id_fkey foreign KEY (quick_task_id) references quick_tasks (id) on delete CASCADE,
  constraint chk_completion_status_valid check (
    (
      (completion_status)::text = any (
        (
          array[
            'submitted'::character varying,
            'verified'::character varying,
            'rejected'::character varying,
            'pending_review'::character varying
          ]
        )::text[]
      )
    )
  ),
  constraint chk_verified_at_when_verified check (
    (
      (
        ((completion_status)::text <> 'verified'::text)
        and (verified_at is null)
      )
      or (
        ((completion_status)::text = 'verified'::text)
        and (verified_at is not null)
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_quick_task_completions_task on public.quick_task_completions using btree (quick_task_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_completions_assignment on public.quick_task_completions using btree (assignment_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_completions_completed_by on public.quick_task_completions using btree (completed_by_user_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_completions_status on public.quick_task_completions using btree (completion_status) TABLESPACE pg_default;

create index IF not exists idx_quick_task_completions_created_at on public.quick_task_completions using btree (created_at desc) TABLESPACE pg_default;

create index IF not exists idx_quick_task_completions_verified_by on public.quick_task_completions using btree (verified_by_user_id) TABLESPACE pg_default
where
  (verified_by_user_id is not null);

create trigger trigger_update_quick_task_completions_updated_at BEFORE
update on quick_task_completions for EACH row
execute FUNCTION update_quick_task_completions_updated_at ();