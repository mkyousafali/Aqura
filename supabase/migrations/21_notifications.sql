-- Migration: Create notifications table
-- File: 21_notifications.sql
-- Description: Creates the notifications table for managing system notifications and messaging

BEGIN;

-- Create trigger functions for notifications
CREATE OR REPLACE FUNCTION trigger_queue_push_notifications()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION queue_quick_task_push_notifications()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create notifications table
CREATE TABLE public.notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title character varying(255) NOT NULL,
  message text NOT NULL,
  created_by character varying(255) NOT NULL DEFAULT 'system'::character varying,
  created_by_name character varying(100) NOT NULL DEFAULT 'System'::character varying,
  created_by_role character varying(50) NOT NULL DEFAULT 'Admin'::character varying,
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
  priority character varying(20) NOT NULL DEFAULT 'medium'::character varying,
  status character varying(20) NOT NULL DEFAULT 'published'::character varying,
  target_type character varying(50) NOT NULL DEFAULT 'all_users'::character varying,
  type character varying(50) NOT NULL DEFAULT 'info'::character varying,
  CONSTRAINT notifications_pkey PRIMARY KEY (id),
  CONSTRAINT notifications_task_assignment_id_fkey FOREIGN KEY (task_assignment_id) REFERENCES task_assignments (id) ON DELETE CASCADE,
  CONSTRAINT notifications_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_notifications_created_at 
ON public.notifications USING btree (created_at DESC) 
TABLESPACE pg_default;

-- Create triggers
CREATE TRIGGER trigger_queue_push_notifications
AFTER INSERT ON notifications 
FOR EACH ROW
EXECUTE FUNCTION trigger_queue_push_notifications();

CREATE TRIGGER trigger_queue_quick_task_push_notifications
AFTER INSERT ON notifications 
FOR EACH ROW
EXECUTE FUNCTION queue_quick_task_push_notifications();

COMMIT;