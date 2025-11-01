create table public.notification_read_states (
  id uuid not null default gen_random_uuid (),
  notification_id uuid not null,
  user_id text not null,
  read_at timestamp with time zone null default now(),
  created_at timestamp with time zone null default now(),
  is_read boolean not null default false,
  constraint notification_read_states_pkey primary key (id),
  constraint notification_read_states_notification_id_user_id_key unique (notification_id, user_id),
  constraint notification_read_states_notification_id_fkey foreign KEY (notification_id) references notifications (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_notification_read_states_notification_id on public.notification_read_states using btree (notification_id) TABLESPACE pg_default;

create index IF not exists idx_notification_read_states_user_id on public.notification_read_states using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_notification_read_states_notification_user on public.notification_read_states using btree (notification_id, user_id) TABLESPACE pg_default;