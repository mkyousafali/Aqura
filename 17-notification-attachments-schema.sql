-- Notification Attachments Schema
-- This table stores file attachments for notifications with metadata tracking

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