-- Migration: Create notification_read_states table
-- File: 19_notification_read_states.sql
-- Description: Creates the notification_read_states table for tracking user read status of notifications

BEGIN;

-- Create notification_read_states table
CREATE TABLE public.notification_read_states (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL,
  user_id text NOT NULL,
  read_at timestamp with time zone NULL DEFAULT now(),
  created_at timestamp with time zone NULL DEFAULT now(),
  is_read boolean NOT NULL DEFAULT false,
  CONSTRAINT notification_read_states_pkey PRIMARY KEY (id),
  CONSTRAINT notification_read_states_notification_id_user_id_key UNIQUE (notification_id, user_id),
  CONSTRAINT notification_read_states_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_id 
ON public.notification_read_states USING btree (notification_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_read_states_user_id 
ON public.notification_read_states USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_user 
ON public.notification_read_states USING btree (notification_id, user_id) 
TABLESPACE pg_default;

COMMIT;