-- Migration: Create task_images table
-- File: 35_task_images.sql
-- Description: Creates the task_images table for managing task-related image attachments

BEGIN;

-- Create task_images table
CREATE TABLE public.task_images (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL,
  file_name text NOT NULL,
  file_size bigint NOT NULL,
  file_type text NOT NULL,
  file_url text NOT NULL,
  image_type text NOT NULL,
  uploaded_by text NOT NULL,
  uploaded_by_name text NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  image_width integer NULL,
  image_height integer NULL,
  file_path text NULL,
  attachment_type text NULL DEFAULT 'task_creation'::text,
  CONSTRAINT task_images_pkey PRIMARY KEY (id),
  CONSTRAINT task_images_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
  CONSTRAINT task_images_attachment_type_check CHECK (
    attachment_type = ANY (
      ARRAY['task_creation'::text, 'task_completion'::text]
    )
  )
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_task_images_task_id 
ON public.task_images USING btree (task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_uploaded_by 
ON public.task_images USING btree (uploaded_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_image_type 
ON public.task_images USING btree (image_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_attachment_type 
ON public.task_images USING btree (attachment_type) 
TABLESPACE pg_default;

COMMIT;