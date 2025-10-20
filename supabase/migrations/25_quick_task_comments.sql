-- Migration: Create quick_task_comments table
-- File: 25_quick_task_comments.sql
-- Description: Creates the quick_task_comments table for managing comments on quick tasks

BEGIN;

-- Create quick_task_comments table
CREATE TABLE public.quick_task_comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  quick_task_id uuid NOT NULL,
  comment text NOT NULL,
  comment_type character varying(50) NULL DEFAULT 'comment'::character varying,
  created_by uuid NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT quick_task_comments_pkey PRIMARY KEY (id),
  CONSTRAINT quick_task_comments_created_by_fkey FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT quick_task_comments_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES quick_tasks (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_quick_task_comments_task 
ON public.quick_task_comments USING btree (quick_task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_comments_created_by 
ON public.quick_task_comments USING btree (created_by) 
TABLESPACE pg_default;

COMMIT;