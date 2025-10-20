-- Migration: Create notification_attachments table
-- File: 17_notification_attachments.sql
-- Description: Creates the notification_attachments table for managing file attachments to notifications

BEGIN;

-- Create notification_attachments table
CREATE TABLE public.notification_attachments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL,
  file_name character varying(255) NOT NULL,
  file_path text NOT NULL,
  file_size bigint NOT NULL,
  file_type character varying(100) NOT NULL,
  uploaded_by character varying(255) NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT notification_attachments_pkey PRIMARY KEY (id),
  CONSTRAINT notification_attachments_notification_fkey FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_notification_attachments_notification_id 
ON public.notification_attachments USING btree (notification_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_attachments_uploaded_by 
ON public.notification_attachments USING btree (uploaded_by) 
TABLESPACE pg_default;

COMMIT;