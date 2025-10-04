-- Notifications Schema
-- This table stores system notifications with comprehensive targeting and metadata support

CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title character varying(255) NOT NULL,
  message text NOT NULL,
  type public.notification_type_enum NOT NULL DEFAULT 'info'::notification_type_enum,
  priority public.notification_priority_enum NOT NULL DEFAULT 'medium'::notification_priority_enum,
  status public.notification_status_enum NOT NULL DEFAULT 'published'::notification_status_enum,
  created_by character varying(255) NOT NULL DEFAULT 'system'::character varying,
  created_by_name character varying(100) NOT NULL DEFAULT 'System'::character varying,
  created_by_role character varying(50) NOT NULL DEFAULT 'Admin'::character varying,
  target_type public.notification_target_type_enum NOT NULL DEFAULT 'all_users'::notification_target_type_enum,
  target_users jsonb NULL,
  target_roles jsonb NULL,
  target_branches jsonb NULL,
  scheduled_for timestamp with time zone NULL,
  sent_at timestamp with time zone NULL DEFAULT now(),
  expires_at timestamp with time zone NULL,
  has_attachments boolean NOT NULL DEFAULT false,
  read_count integer NOT NULL DEFAULT 0,
  total_recipients integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  deleted_at timestamp with time zone NULL,
  metadata jsonb NULL,
  task_id uuid NULL,
  task_assignment_id uuid NULL,
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_task_assignment_id_fkey FOREIGN KEY (task_assignment_id) REFERENCES task_assignments (id) ON DELETE CASCADE,
  CONSTRAINT notifications_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_notifications_type ON public.notifications USING btree (type) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_priority ON public.notifications USING btree (priority) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_status ON public.notifications USING btree (status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications USING btree (created_at DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notifications_target_type ON public.notifications USING btree (target_type) TABLESPACE pg_default;

-- Trigger to queue push notifications when notifications are created or updated
CREATE TRIGGER trigger_queue_push_notification
AFTER INSERT
OR UPDATE ON notifications FOR EACH ROW
EXECUTE FUNCTION trigger_queue_push_notification();