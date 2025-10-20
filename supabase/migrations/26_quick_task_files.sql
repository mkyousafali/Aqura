-- Migration: Create quick_task_files table
-- File: 26_quick_task_files.sql
-- Description: Creates the quick_task_files table for managing file attachments on quick tasks

BEGIN;

-- Create quick_task_files table
CREATE TABLE public.quick_task_files (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  quick_task_id uuid NOT NULL,
  file_name character varying(255) NOT NULL,
  file_type character varying(100) NULL,
  file_size integer NULL,
  mime_type character varying(100) NULL,
  storage_path text NOT NULL,
  storage_bucket character varying(100) NULL DEFAULT 'quick-task-files'::character varying,
  uploaded_by uuid NULL,
  uploaded_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT quick_task_files_pkey PRIMARY KEY (id),
  CONSTRAINT quick_task_files_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES quick_tasks (id) ON DELETE CASCADE,
  CONSTRAINT quick_task_files_uploaded_by_fkey FOREIGN KEY (uploaded_by) REFERENCES users (id) ON DELETE SET NULL
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_quick_task_files_task 
ON public.quick_task_files USING btree (quick_task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_files_uploaded_by 
ON public.quick_task_files USING btree (uploaded_by) 
TABLESPACE pg_default;

COMMIT;