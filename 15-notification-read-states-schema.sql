-- Table 15: Notification Read States
-- Purpose: Tracks which users have read which notifications with timestamps
-- Created: 2025-09-29

CREATE TABLE public.notification_read_states (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL,
  user_id text NOT NULL,
  read_at timestamp with time zone NULL DEFAULT now(),
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT notification_read_states_pkey PRIMARY KEY (id),
  CONSTRAINT notification_read_states_notification_id_user_id_key UNIQUE (notification_id, user_id),
  CONSTRAINT notification_read_states_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_id 
  ON public.notification_read_states USING btree (notification_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_read_states_user_id 
  ON public.notification_read_states USING btree (user_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_user 
  ON public.notification_read_states USING btree (notification_id, user_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_read_states_read_at 
  ON public.notification_read_states USING btree (read_at) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_read_states_created_at 
  ON public.notification_read_states USING btree (created_at) TABLESPACE pg_default;

-- Comments for documentation
COMMENT ON TABLE public.notification_read_states IS 'Tracks read status of notifications per user with timestamps';
COMMENT ON COLUMN public.notification_read_states.id IS 'Primary key - UUID generated with gen_random_uuid()';
COMMENT ON COLUMN public.notification_read_states.notification_id IS 'Foreign key reference to notifications table (required, cascading delete)';
COMMENT ON COLUMN public.notification_read_states.user_id IS 'Identifier of the user who read the notification (required)';
COMMENT ON COLUMN public.notification_read_states.read_at IS 'Timestamp when the notification was read (auto-set to now)';
COMMENT ON COLUMN public.notification_read_states.created_at IS 'Timestamp when the read state record was created (auto-set)';