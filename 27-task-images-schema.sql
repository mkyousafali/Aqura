-- Task Images Schema
-- This table stores image attachments for tasks with metadata tracking

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
  CONSTRAINT task_images_pkey PRIMARY KEY (id),
  CONSTRAINT task_images_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_task_images_task_id ON public.task_images USING btree (task_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_uploaded_by ON public.task_images USING btree (uploaded_by) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_images_image_type ON public.task_images USING btree (image_type) TABLESPACE pg_default;