-- Notification Recipients Schema
-- This table manages notification recipients with read/dismiss status tracking

CREATE TABLE public.notification_recipients (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL,
  user_id character varying(255) NOT NULL,
  role character varying(100) NULL,
  branch_id character varying(255) NULL,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamp with time zone NULL,
  is_dismissed boolean NOT NULL DEFAULT false,
  dismissed_at timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notification_recipients_pkey PRIMARY KEY (id),
  CONSTRAINT notification_recipients_unique UNIQUE (notification_id, user_id),
  CONSTRAINT notification_recipients_notification_fkey FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_notification_recipients_user_id ON public.notification_recipients USING btree (user_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_recipients_unread ON public.notification_recipients USING btree (user_id, is_read) TABLESPACE pg_default
WHERE (is_read = false);