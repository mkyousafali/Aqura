create table public.user_sessions (
  id uuid not null default extensions.uuid_generate_v4 (),
  user_id uuid not null,
  session_token character varying(255) not null,
  login_method character varying(20) not null,
  ip_address inet null,
  user_agent text null,
  is_active boolean null default true,
  expires_at timestamp with time zone not null,
  created_at timestamp with time zone null default now(),
  ended_at timestamp with time zone null,
  constraint user_sessions_pkey primary key (id),
  constraint user_sessions_session_token_key unique (session_token),
  constraint user_sessions_user_id_fkey foreign KEY (user_id) references users (id) on delete CASCADE,
  constraint user_sessions_login_method_check check (
    (
      (login_method)::text = any (
        (
          array[
            'quick_access'::character varying,
            'username_password'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_user_sessions_user_id on public.user_sessions using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_user_sessions_token on public.user_sessions using btree (session_token) TABLESPACE pg_default;

create index IF not exists idx_user_sessions_active on public.user_sessions using btree (is_active) TABLESPACE pg_default;