create table public.notifications (
  id uuid not null default gen_random_uuid (),
  title character varying(255) not null,
  message text not null,
  created_by character varying(255) not null default 'system'::character varying,
  created_by_name character varying(100) not null default 'System'::character varying,
  created_by_role character varying(50) not null default 'Admin'::character varying,
  target_users jsonb null,
  target_roles jsonb null,
  target_branches jsonb null,
  scheduled_for timestamp with time zone null,
  sent_at timestamp with time zone null default now(),
  expires_at timestamp with time zone null,
  has_attachments boolean not null default false,
  read_count integer not null default 0,
  total_recipients integer not null default 0,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  deleted_at timestamp with time zone null,
  metadata jsonb null,
  task_id uuid null,
  task_assignment_id uuid null,
  priority character varying(20) not null default 'medium'::character varying,
  status character varying(20) not null default 'published'::character varying,
  target_type character varying(50) not null default 'all_users'::character varying,
  type character varying(50) not null default 'info'::character varying,
  constraint notifications_pkey primary key (id),
  constraint notifications_task_assignment_id_fkey foreign KEY (task_assignment_id) references task_assignments (id) on delete CASCADE,
  constraint notifications_task_id_fkey foreign KEY (task_id) references tasks (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_notifications_created_at on public.notifications using btree (created_at desc) TABLESPACE pg_default;

create trigger trigger_queue_push_notifications
after INSERT on notifications for EACH row
execute FUNCTION trigger_queue_push_notifications ();

create trigger trigger_queue_quick_task_push_notifications
after INSERT on notifications for EACH row
execute FUNCTION queue_quick_task_push_notifications ();


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


  create table public.users (
  id uuid not null default extensions.uuid_generate_v4 (),
  username character varying(50) not null,
  password_hash character varying(255) not null,
  salt character varying(100) not null,
  quick_access_code character varying(6) not null,
  quick_access_salt character varying(100) not null,
  user_type public.user_type_enum not null default 'branch_specific'::user_type_enum,
  employee_id uuid null,
  branch_id bigint null,
  role_type public.role_type_enum null default 'Position-based'::role_type_enum,
  position_id uuid null,
  avatar text null,
  avatar_small_url text null,
  avatar_medium_url text null,
  avatar_large_url text null,
  is_first_login boolean null default true,
  failed_login_attempts integer null default 0,
  locked_at timestamp with time zone null,
  locked_by uuid null,
  last_login_at timestamp with time zone null,
  password_expires_at timestamp with time zone null,
  last_password_change timestamp with time zone null default now(),
  created_by bigint null,
  updated_by bigint null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  status character varying(20) not null default 'active'::character varying,
  constraint users_pkey primary key (id),
  constraint users_username_key unique (username),
  constraint users_quick_access_code_key unique (quick_access_code),
  constraint users_locked_by_fkey foreign KEY (locked_by) references users (id),
  constraint users_branch_id_fkey foreign KEY (branch_id) references branches (id) on delete set null,
  constraint users_employee_id_fkey foreign KEY (employee_id) references hr_employees (id) on delete set null,
  constraint users_employee_branch_check check (
    (
      (user_type = 'global'::user_type_enum)
      or (
        (user_type = 'branch_specific'::user_type_enum)
        and (branch_id is not null)
      )
    )
  ),
  constraint users_quick_access_length check ((length((quick_access_code)::text) = 6)),
  constraint users_quick_access_numeric check (((quick_access_code)::text ~ '^[0-9]{6}$'::text))
) TABLESPACE pg_default;

create index IF not exists idx_users_username on public.users using btree (username) TABLESPACE pg_default;

create unique INDEX IF not exists idx_users_quick_access on public.users using btree (quick_access_code) TABLESPACE pg_default;

create index IF not exists idx_users_role_type on public.users using btree (role_type) TABLESPACE pg_default;

create index IF not exists idx_users_employee_id on public.users using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_users_branch_id on public.users using btree (branch_id) TABLESPACE pg_default;

create index IF not exists idx_users_created_at on public.users using btree (created_at) TABLESPACE pg_default;

create index IF not exists idx_users_last_login on public.users using btree (last_login_at) TABLESPACE pg_default;

create index IF not exists idx_users_employee_lookup on public.users using btree (employee_id) TABLESPACE pg_default
where
  (employee_id is not null);

create index IF not exists idx_users_branch_lookup on public.users using btree (branch_id) TABLESPACE pg_default
where
  (branch_id is not null);

create index IF not exists idx_users_position_lookup on public.users using btree (position_id) TABLESPACE pg_default
where
  (position_id is not null);

create trigger update_users_updated_at BEFORE
update on users for EACH row
execute FUNCTION update_updated_at_column ();

create trigger users_audit_trigger
after INSERT
or DELETE
or
update on users for EACH row
execute FUNCTION log_user_action ();


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

