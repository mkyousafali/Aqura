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

create table public.quick_tasks (
  id uuid not null default gen_random_uuid (),
  title character varying(255) not null,
  description text null,
  price_tag character varying(50) null,
  issue_type character varying(100) not null,
  priority character varying(50) not null,
  assigned_by uuid not null,
  assigned_to_branch_id bigint null,
  created_at timestamp with time zone null default now(),
  deadline_datetime timestamp with time zone null default (now() + '24:00:00'::interval),
  completed_at timestamp with time zone null,
  status character varying(50) null default 'pending'::character varying,
  created_from character varying(50) null default 'quick_task'::character varying,
  updated_at timestamp with time zone null default now(),
  constraint quick_tasks_pkey primary key (id),
  constraint quick_tasks_assigned_by_fkey foreign KEY (assigned_by) references users (id) on delete CASCADE,
  constraint quick_tasks_assigned_to_branch_id_fkey foreign KEY (assigned_to_branch_id) references branches (id) on delete set null
) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_assigned_by on public.quick_tasks using btree (assigned_by) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_branch on public.quick_tasks using btree (assigned_to_branch_id) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_status on public.quick_tasks using btree (status) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_deadline on public.quick_tasks using btree (deadline_datetime) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_created_at on public.quick_tasks using btree (created_at) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_issue_type on public.quick_tasks using btree (issue_type) TABLESPACE pg_default;

create index IF not exists idx_quick_tasks_priority on public.quick_tasks using btree (priority) TABLESPACE pg_default;

create table public.quick_task_assignments (
  id uuid not null default gen_random_uuid (),
  quick_task_id uuid not null,
  assigned_to_user_id uuid not null,
  status character varying(50) null default 'pending'::character varying,
  accepted_at timestamp with time zone null,
  started_at timestamp with time zone null,
  completed_at timestamp with time zone null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint quick_task_assignments_pkey primary key (id),
  constraint quick_task_assignments_quick_task_id_assigned_to_user_id_key unique (quick_task_id, assigned_to_user_id),
  constraint quick_task_assignments_assigned_to_user_id_fkey foreign KEY (assigned_to_user_id) references users (id) on delete CASCADE,
  constraint quick_task_assignments_quick_task_id_fkey foreign KEY (quick_task_id) references quick_tasks (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_task on public.quick_task_assignments using btree (quick_task_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_user on public.quick_task_assignments using btree (assigned_to_user_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_status on public.quick_task_assignments using btree (status) TABLESPACE pg_default;

create index IF not exists idx_quick_task_assignments_created_at on public.quick_task_assignments using btree (created_at) TABLESPACE pg_default;

create trigger trigger_create_quick_task_notification
after INSERT on quick_task_assignments for EACH row
execute FUNCTION create_quick_task_notification ();

create trigger trigger_update_quick_task_status
after
update on quick_task_assignments for EACH row
execute FUNCTION update_quick_task_status ();

create table public.task_assignments (
  id uuid not null default gen_random_uuid (),
  task_id uuid not null,
  assignment_type text not null,
  assigned_to_user_id text null,
  assigned_to_branch_id uuid null,
  assigned_by text not null,
  assigned_by_name text null,
  assigned_at timestamp with time zone null default now(),
  status text null default 'assigned'::text,
  started_at timestamp with time zone null,
  completed_at timestamp with time zone null,
  schedule_date date null,
  schedule_time time without time zone null,
  deadline_date date null,
  deadline_time time without time zone null,
  deadline_datetime timestamp with time zone null,
  is_reassignable boolean null default true,
  is_recurring boolean null default false,
  recurring_pattern jsonb null,
  notes text null,
  priority_override text null,
  require_task_finished boolean null default true,
  require_photo_upload boolean null default false,
  require_erp_reference boolean null default false,
  reassigned_from uuid null,
  reassignment_reason text null,
  reassigned_at timestamp with time zone null,
  constraint task_assignments_pkey primary key (id),
  constraint task_assignments_task_id_assignment_type_assigned_to_user_i_key unique (
    task_id,
    assignment_type,
    assigned_to_user_id,
    assigned_to_branch_id
  ),
  constraint fk_task_assignments_reassigned_from foreign KEY (reassigned_from) references task_assignments (id) on delete set null,
  constraint task_assignments_task_id_fkey foreign KEY (task_id) references tasks (id) on delete CASCADE,
  constraint chk_schedule_consistency check (
    (
      (
        (schedule_date is null)
        and (schedule_time is null)
      )
      or (schedule_date is not null)
    )
  ),
  constraint chk_priority_override_valid check (
    (
      (priority_override is null)
      or (
        priority_override = any (
          array[
            'low'::text,
            'medium'::text,
            'high'::text,
            'urgent'::text
          ]
        )
      )
    )
  ),
  constraint chk_deadline_consistency check (
    (
      (
        (deadline_date is null)
        and (deadline_time is null)
      )
      or (deadline_date is not null)
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_task_id on public.task_assignments using btree (task_id) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_assigned_to_user_id on public.task_assignments using btree (assigned_to_user_id) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_assigned_to_branch_id on public.task_assignments using btree (assigned_to_branch_id) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_assignment_type on public.task_assignments using btree (assignment_type) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_status on public.task_assignments using btree (status) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_assigned_by on public.task_assignments using btree (assigned_by) TABLESPACE pg_default;

create index IF not exists idx_task_assignments_deadline_datetime on public.task_assignments using btree (deadline_datetime) TABLESPACE pg_default
where
  (deadline_datetime is not null);

create index IF not exists idx_task_assignments_schedule_date on public.task_assignments using btree (schedule_date) TABLESPACE pg_default
where
  (schedule_date is not null);

create index IF not exists idx_task_assignments_recurring on public.task_assignments using btree (is_recurring, status) TABLESPACE pg_default
where
  (is_recurring = true);

create index IF not exists idx_task_assignments_reassignable on public.task_assignments using btree (is_reassignable, status) TABLESPACE pg_default
where
  (is_reassignable = true);

create index IF not exists idx_task_assignments_overdue on public.task_assignments using btree (deadline_datetime, status) TABLESPACE pg_default
where
  (
    (deadline_datetime is not null)
    and (
      status <> all (array['completed'::text, 'cancelled'::text])
    )
  );

create trigger cleanup_assignment_notifications_trigger
after DELETE on task_assignments for EACH row
execute FUNCTION trigger_cleanup_assignment_notifications ();

create trigger trigger_update_deadline_datetime BEFORE INSERT
or
update OF deadline_date,
deadline_time on task_assignments for EACH row
execute FUNCTION update_deadline_datetime ();

create table public.hr_employees (
  id uuid not null default extensions.uuid_generate_v4 (),
  employee_id character varying(10) not null,
  branch_id bigint not null,
  hire_date date null,
  status character varying(20) null default 'active'::character varying,
  created_at timestamp with time zone null default now(),
  name character varying(200) not null,
  constraint hr_employees_pkey primary key (id),
  constraint hr_employees_employee_id_branch_id_unique unique (employee_id, branch_id),
  constraint hr_employees_branch_id_fkey foreign KEY (branch_id) references branches (id)
) TABLESPACE pg_default;

create index IF not exists idx_hr_employees_employee_id_branch_id on public.hr_employees using btree (employee_id, branch_id) TABLESPACE pg_default;

create index IF not exists idx_hr_employees_employee_id on public.hr_employees using btree (employee_id) TABLESPACE pg_default;

create index IF not exists idx_hr_employees_branch_id on public.hr_employees using btree (branch_id) TABLESPACE pg_default;

create table public.quick_task_files (
  id uuid not null default gen_random_uuid (),
  quick_task_id uuid not null,
  file_name character varying(255) not null,
  file_type character varying(100) null,
  file_size integer null,
  mime_type character varying(100) null,
  storage_path text not null,
  storage_bucket character varying(100) null default 'quick-task-files'::character varying,
  uploaded_by uuid null,
  uploaded_at timestamp with time zone null default now(),
  constraint quick_task_files_pkey primary key (id),
  constraint quick_task_files_quick_task_id_fkey foreign KEY (quick_task_id) references quick_tasks (id) on delete CASCADE,
  constraint quick_task_files_uploaded_by_fkey foreign KEY (uploaded_by) references users (id) on delete set null
) TABLESPACE pg_default;

create index IF not exists idx_quick_task_files_task on public.quick_task_files using btree (quick_task_id) TABLESPACE pg_default;

create index IF not exists idx_quick_task_files_uploaded_by on public.quick_task_files using btree (uploaded_by) TABLESPACE pg_default;

create table public.task_images (
  id uuid not null default gen_random_uuid (),
  task_id uuid not null,
  file_name text not null,
  file_size bigint not null,
  file_type text not null,
  file_url text not null,
  image_type text not null,
  uploaded_by text not null,
  uploaded_by_name text null,
  created_at timestamp with time zone null default now(),
  image_width integer null,
  image_height integer null,
  file_path text null,
  attachment_type text null default 'task_creation'::text,
  constraint task_images_pkey primary key (id),
  constraint task_images_task_id_fkey foreign KEY (task_id) references tasks (id) on delete CASCADE,
  constraint task_images_attachment_type_check check (
    (
      attachment_type = any (
        array['task_creation'::text, 'task_completion'::text]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_task_images_task_id on public.task_images using btree (task_id) TABLESPACE pg_default;

create index IF not exists idx_task_images_uploaded_by on public.task_images using btree (uploaded_by) TABLESPACE pg_default;

create index IF not exists idx_task_images_image_type on public.task_images using btree (image_type) TABLESPACE pg_default;

create index IF not exists idx_task_images_attachment_type on public.task_images using btree (attachment_type) TABLESPACE pg_default;

create table public.notification_attachments (
  id uuid not null default gen_random_uuid (),
  notification_id uuid not null,
  file_name character varying(255) not null,
  file_path text not null,
  file_size bigint not null,
  file_type character varying(100) not null,
  uploaded_by character varying(255) not null,
  created_at timestamp with time zone not null default now(),
  constraint notification_attachments_pkey primary key (id),
  constraint notification_attachments_notification_fkey foreign KEY (notification_id) references notifications (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_notification_attachments_notification_id on public.notification_attachments using btree (notification_id) TABLESPACE pg_default;

create index IF not exists idx_notification_attachments_uploaded_by on public.notification_attachments using btree (uploaded_by) TABLESPACE pg_default;