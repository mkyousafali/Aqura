-- Migration: Create notification_recipients table
-- File: 20_notification_recipients.sql
-- Description: Creates the notification_recipients table for managing notification recipients and delivery status

BEGIN;

-- Create notification_recipients table
CREATE TABLE public.notification_recipients (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL,
  role character varying(100) NULL,
  branch_id character varying(255) NULL,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamp with time zone NULL,
  is_dismissed boolean NOT NULL DEFAULT false,
  dismissed_at timestamp with time zone NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  delivery_status character varying(20) NULL DEFAULT 'pending'::character varying,
  delivery_attempted_at timestamp with time zone NULL,
  error_message text NULL,
  user_id uuid NULL,
  CONSTRAINT notification_recipients_pkey PRIMARY KEY (id),
  CONSTRAINT unique_notification_recipient UNIQUE (notification_id, user_id),
  CONSTRAINT fk_notification_recipients_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT notification_recipients_notification_fkey FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_notification_recipients_delivery_status 
ON public.notification_recipients USING btree (delivery_status) 
TABLESPACE pg_default
WHERE (
  (delivery_status)::text = ANY (
    (
      ARRAY[
        'pending'::character varying,
        'failed'::character varying
      ]
    )::text[]
  )
);

COMMIT;