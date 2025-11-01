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