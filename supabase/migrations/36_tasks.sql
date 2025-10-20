-- Migration: Create tasks table
-- File: 36_tasks.sql
-- Description: Creates the tasks table for managing general task records

BEGIN;

-- Create tasks table
CREATE TABLE public.tasks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NULL,
  require_task_finished boolean NULL DEFAULT false,
  require_photo_upload boolean NULL DEFAULT false,
  require_erp_reference boolean NULL DEFAULT false,
  can_escalate boolean NULL DEFAULT false,
  can_reassign boolean NULL DEFAULT false,
  created_by text NOT NULL,
  created_by_name text NULL,
  created_by_role text NULL,
  status text NULL DEFAULT 'draft'::text,
  priority text NULL DEFAULT 'medium'::text,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  deleted_at timestamp with time zone NULL,
  due_date date NULL,
  due_time time without time zone NULL,
  due_datetime timestamp with time zone NULL,
  search_vector tsvector GENERATED ALWAYS AS (
    to_tsvector(
      'english'::regconfig,
      (
        (title || ' '::text) || COALESCE(description, ''::text)
      )
    )
  ) STORED NULL,
  CONSTRAINT tasks_pkey PRIMARY KEY (id),
  CONSTRAINT tasks_priority_check CHECK (
    priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text])
  )
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_tasks_created_by 
ON public.tasks USING btree (created_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_status 
ON public.tasks USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_created_at 
ON public.tasks USING btree (created_at DESC) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at 
ON public.tasks USING btree (deleted_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_search_vector 
ON public.tasks USING gin (search_vector) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_due_date 
ON public.tasks USING btree (due_date) 
TABLESPACE pg_default
WHERE (due_date IS NOT NULL);

-- Create trigger
CREATE TRIGGER cleanup_task_notifications_trigger
AFTER DELETE ON tasks 
FOR EACH ROW
EXECUTE FUNCTION trigger_cleanup_task_notifications();

COMMIT;