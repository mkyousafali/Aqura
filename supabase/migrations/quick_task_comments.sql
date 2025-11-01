create table public.quick_task_comments (
  id uuid not null default gen_random_uuid (),
  quick_task_id uuid not null,
  comment text not null,
  comment_type character varying(50) null default 'comment'::character varying,
  created_by uuid null,
  created_at timestamp with time zone null default now(),
  constraint quick_task_comments_pkey primary key (id),
  constraint quick_task_comments_created_by_fkey foreign KEY (created_by) references users (id) on delete set null,
  constraint quick_task_comments_quick_task_id_fkey foreign KEY (quick_task_id) references quick_tasks (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_quick_task_comments_task on public.quick_task_comments using btree (quick_task_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_comments_created_by on public.quick_task_comments using btree (created_by) TABLESPACE pg_default;