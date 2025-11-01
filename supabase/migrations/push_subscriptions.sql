create table public.push_subscriptions (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  device_id character varying(100) not null,
  endpoint text not null,
  p256dh text not null,
  auth text not null,
  device_type character varying(20) not null,
  browser_name character varying(50) null,
  user_agent text null,
  is_active boolean null default true,
  last_seen timestamp with time zone null default now(),
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  session_id text null,
  constraint push_subscriptions_pkey primary key (id),
  constraint unique_session_subscription unique (user_id, session_id, endpoint),
  constraint push_subscriptions_user_id_fkey foreign KEY (user_id) references users (id) on delete CASCADE,
  constraint push_subscriptions_device_type_check check (
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

create index IF not exists idx_push_subscriptions_user_id on public.push_subscriptions using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_push_subscriptions_device_id on public.push_subscriptions using btree (device_id) TABLESPACE pg_default;

create index IF not exists idx_push_subscriptions_active on public.push_subscriptions using btree (is_active) TABLESPACE pg_default;

create index IF not exists idx_push_subscriptions_last_seen on public.push_subscriptions using btree (last_seen) TABLESPACE pg_default;

create index IF not exists idx_push_subscriptions_session on public.push_subscriptions using btree (user_id, device_id, session_id) TABLESPACE pg_default
where
  (is_active = true);

create index IF not exists idx_push_subscriptions_cleanup on public.push_subscriptions using btree (user_id, last_seen, is_active) TABLESPACE pg_default;

create index IF not exists idx_push_subscriptions_active_user on public.push_subscriptions using btree (user_id, is_active) TABLESPACE pg_default
where
  (is_active = true);

create index IF not exists idx_push_subscriptions_device_session on public.push_subscriptions using btree (device_id, session_id, is_active) TABLESPACE pg_default;

create trigger trigger_push_subscriptions_updated_at BEFORE
update on push_subscriptions for EACH row
execute FUNCTION update_push_subscriptions_updated_at ();

create trigger trigger_update_push_subscriptions_updated_at BEFORE
update on push_subscriptions for EACH row
execute FUNCTION update_push_subscriptions_updated_at ();