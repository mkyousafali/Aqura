create table public.user_password_history (
  id uuid not null default extensions.uuid_generate_v4 (),
  user_id uuid not null,
  password_hash character varying(255) not null,
  salt character varying(100) not null,
  created_at timestamp with time zone null default now(),
  constraint user_password_history_pkey primary key (id),
  constraint user_password_history_user_id_fkey foreign KEY (user_id) references users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_password_history_user_created on public.user_password_history using btree (user_id, created_at desc) TABLESPACE pg_default;