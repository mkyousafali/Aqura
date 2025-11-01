create table public.user_device_sessions (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  device_id character varying(100) not null,
  session_token character varying(255) not null,
  device_type character varying(20) not null,
  browser_name character varying(50) null,
  user_agent text null,
  ip_address inet null,
  is_active boolean null default true,
  login_at timestamp with time zone null default now(),
  last_activity timestamp with time zone null default now(),
  expires_at timestamp with time zone null default (now() + '24:00:00'::interval),
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint user_device_sessions_pkey primary key (id),
  constraint user_device_sessions_user_id_device_id_key unique (user_id, device_id),
  constraint user_device_sessions_user_id_fkey foreign KEY (user_id) references users (id) on delete CASCADE,
  constraint user_device_sessions_device_type_check check (
    (
      (device_type)::text = any (
        (
          array[
            'mobile'::character varying,
            'desktop'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_user_device_sessions_user_id on public.user_device_sessions using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_user_device_sessions_device_id on public.user_device_sessions using btree (device_id) TABLESPACE pg_default;

create index IF not exists idx_user_device_sessions_active on public.user_device_sessions using btree (is_active) TABLESPACE pg_default;

create index IF not exists idx_user_device_sessions_expires_at on public.user_device_sessions using btree (expires_at) TABLESPACE pg_default;

create index IF not exists idx_user_device_sessions_last_activity on public.user_device_sessions using btree (last_activity) TABLESPACE pg_default;

create trigger trigger_user_device_sessions_updated_at BEFORE
update on user_device_sessions for EACH row
execute FUNCTION update_user_device_sessions_updated_at ();