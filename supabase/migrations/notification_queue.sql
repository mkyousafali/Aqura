create table public.notification_queue (
  id uuid not null default gen_random_uuid (),
  notification_id uuid not null,
  user_id uuid not null,
  device_id character varying(100) null,
  push_subscription_id uuid null,
  status character varying(20) null default 'pending'::character varying,
  payload jsonb not null,
  scheduled_at timestamp with time zone null default now(),
  sent_at timestamp with time zone null,
  delivered_at timestamp with time zone null,
  error_message text null,
  retry_count integer null default 0,
  max_retries integer null default 3,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  next_retry_at timestamp with time zone null,
  last_attempt_at timestamp with time zone null,
  renotification_at timestamp with time zone null,
  notification_priority text null default 'normal'::text,
  constraint notification_queue_pkey primary key (id),
  constraint notification_queue_notification_id_fkey foreign KEY (notification_id) references notifications (id) on delete CASCADE,
  constraint notification_queue_push_subscription_id_fkey foreign KEY (push_subscription_id) references push_subscriptions (id) on delete set null,
  constraint notification_queue_user_id_fkey foreign KEY (user_id) references users (id) on delete CASCADE,
  constraint notification_queue_status_check check (
    (
      (status)::text = any (
        (
          array[
            'pending'::character varying,
            'sent'::character varying,
            'delivered'::character varying,
            'failed'::character varying,
            'retry'::character varying,
            'processing'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_notification_queue_notification_id on public.notification_queue using btree (notification_id) TABLESPACE pg_default;

create index IF not exists idx_notification_queue_user_id on public.notification_queue using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_notification_queue_status on public.notification_queue using btree (status) TABLESPACE pg_default;

create index IF not exists idx_notification_queue_scheduled_at on public.notification_queue using btree (scheduled_at) TABLESPACE pg_default;

create index IF not exists idx_notification_queue_retry_count on public.notification_queue using btree (retry_count) TABLESPACE pg_default;

create index IF not exists idx_notification_queue_renotify on public.notification_queue using btree (renotification_at) TABLESPACE pg_default
where
  (
    (status)::text = any (
      (
        array[
          'failed'::character varying,
          'retry'::character varying
        ]
      )::text[]
    )
  );

create index IF not exists idx_notification_queue_priority on public.notification_queue using btree (notification_priority, status) TABLESPACE pg_default;

create index IF not exists idx_notification_queue_retry on public.notification_queue using btree (status, next_retry_at) TABLESPACE pg_default
where
  (
    ((status)::text = 'retry'::text)
    and (next_retry_at is not null)
  );

create index IF not exists idx_notification_queue_processing on public.notification_queue using btree (status, last_attempt_at) TABLESPACE pg_default
where
  (
    (status)::text = any (
      (
        array[
          'pending'::character varying,
          'processing'::character varying,
          'retry'::character varying
        ]
      )::text[]
    )
  );

create index IF not exists idx_notification_queue_lookup on public.notification_queue using btree (notification_id, user_id, device_id, status) TABLESPACE pg_default;

create index IF not exists idx_notification_queue_notification_user_subscription on public.notification_queue using btree (notification_id, user_id, push_subscription_id) TABLESPACE pg_default;

create index IF not exists idx_notification_queue_duplicate_prevention on public.notification_queue using btree (
  notification_id,
  user_id,
  push_subscription_id,
  device_id
) TABLESPACE pg_default;

create index IF not exists idx_notification_queue_status_created on public.notification_queue using btree (status, created_at) TABLESPACE pg_default;

create trigger trigger_notification_queue_updated_at BEFORE
update on notification_queue for EACH row
execute FUNCTION update_notification_queue_updated_at ();

create trigger trigger_schedule_renotification BEFORE
update on notification_queue for EACH row when (
  old.status::text is distinct from new.status::text
  and new.status::text = 'failed'::text
)
execute FUNCTION schedule_renotification ();

create trigger trigger_update_delivery_status
after
update OF status on notification_queue for EACH row when (
  new.status::text = any (
    array[
      'sent'::character varying,
      'failed'::character varying
    ]::text[]
  )
)
execute FUNCTION update_notification_delivery_status ();