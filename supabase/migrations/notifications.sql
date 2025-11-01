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

create trigger trigger_create_notification_recipients
after INSERT on notifications for EACH row when (new.status::text = 'published'::text)
execute FUNCTION create_notification_recipients ();

create trigger trigger_queue_push_notification
after INSERT on notifications for EACH row when (new.status::text = 'published'::text)
execute FUNCTION queue_push_notification_trigger ();