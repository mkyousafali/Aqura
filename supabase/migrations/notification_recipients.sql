create table public.notification_recipients (
  id uuid not null default gen_random_uuid (),
  notification_id uuid not null,
  role character varying(100) null,
  branch_id character varying(255) null,
  is_read boolean not null default false,
  read_at timestamp with time zone null,
  is_dismissed boolean not null default false,
  dismissed_at timestamp with time zone null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  delivery_status character varying(20) null default 'pending'::character varying,
  delivery_attempted_at timestamp with time zone null,
  error_message text null,
  user_id uuid null,
  constraint notification_recipients_pkey primary key (id),
  constraint unique_notification_recipient unique (notification_id, user_id),
  constraint fk_notification_recipients_user foreign KEY (user_id) references users (id) on delete CASCADE,
  constraint notification_recipients_notification_fkey foreign KEY (notification_id) references notifications (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_notification_recipients_delivery_status on public.notification_recipients using btree (delivery_status) TABLESPACE pg_default
where
  (
    (delivery_status)::text = any (
      (
        array[
          'pending'::character varying,
          'failed'::character varying
        ]
      )::text[]
    )
  );