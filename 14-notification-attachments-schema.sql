-- Table 14: Notification Attachments
-- Purpose: Manages file attachments for notifications with metadata tracking
-- Created: 2025-09-29

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

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_notification_attachments_notification_id 
  ON public.notification_attachments USING btree (notification_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_attachments_file_type 
  ON public.notification_attachments USING btree (file_type) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_attachments_uploaded_by 
  ON public.notification_attachments USING btree (uploaded_by) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_attachments_created_at 
  ON public.notification_attachments USING btree (created_at) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_attachments_file_size 
  ON public.notification_attachments USING btree (file_size) TABLESPACE pg_default;

-- Comments for documentation
COMMENT ON TABLE public.notification_attachments IS 'File attachments for notifications with metadata and cascade delete';
COMMENT ON COLUMN public.notification_attachments.id IS 'Primary key - UUID generated with gen_random_uuid()';
COMMENT ON COLUMN public.notification_attachments.notification_id IS 'Foreign key reference to notifications table (required, cascading delete)';
COMMENT ON COLUMN public.notification_attachments.file_name IS 'Original name of the uploaded file (required)';
COMMENT ON COLUMN public.notification_attachments.file_path IS 'Full path or URL to the stored file (required)';
COMMENT ON COLUMN public.notification_attachments.file_size IS 'Size of the file in bytes (required)';
COMMENT ON COLUMN public.notification_attachments.file_type IS 'MIME type or file extension of the attachment (required)';
COMMENT ON COLUMN public.notification_attachments.uploaded_by IS 'Identifier of the user who uploaded the file (required)';
COMMENT ON COLUMN public.notification_attachments.created_at IS 'Timestamp when the attachment was uploaded (auto-set)';