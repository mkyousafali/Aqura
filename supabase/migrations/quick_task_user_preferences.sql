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