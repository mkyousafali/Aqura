-- Migration: Create quick_tasks table
-- File: 28_quick_tasks.sql
-- Description: Creates the quick_tasks table for managing quick task records

BEGIN;

-- Create quick_tasks table
CREATE TABLE public.quick_tasks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title character varying(255) NOT NULL,
  description text NULL,
  price_tag character varying(50) NULL,
  issue_type character varying(100) NOT NULL,
  priority character varying(50) NOT NULL,
  assigned_by uuid NOT NULL,
  assigned_to_branch_id bigint NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  deadline_datetime timestamp with time zone NULL DEFAULT (now() + '24:00:00'::interval),
  completed_at timestamp with time zone NULL,
  status character varying(50) NULL DEFAULT 'pending'::character varying,
  created_from character varying(50) NULL DEFAULT 'quick_task'::character varying,
  updated_at timestamp with time zone NULL DEFAULT now(),
  require_task_finished boolean NULL DEFAULT true,
  require_photo_upload boolean NULL DEFAULT false,
  require_erp_reference boolean NULL DEFAULT false,
  CONSTRAINT quick_tasks_pkey PRIMARY KEY (id),
  CONSTRAINT quick_tasks_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT quick_tasks_assigned_to_branch_id_fkey FOREIGN KEY (assigned_to_branch_id) REFERENCES branches (id) ON DELETE SET NULL,
  CONSTRAINT chk_require_task_finished_not_null CHECK ((require_task_finished IS NOT NULL))
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_quick_tasks_assigned_by 
ON public.quick_tasks USING btree (assigned_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_branch 
ON public.quick_tasks USING btree (assigned_to_branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_status 
ON public.quick_tasks USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_deadline 
ON public.quick_tasks USING btree (deadline_datetime) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_created_at 
ON public.quick_tasks USING btree (created_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_issue_type 
ON public.quick_tasks USING btree (issue_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_priority 
ON public.quick_tasks USING btree (priority) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_require_photo_upload 
ON public.quick_tasks USING btree (require_photo_upload) 
TABLESPACE pg_default
WHERE (require_photo_upload = true);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_require_erp_reference 
ON public.quick_tasks USING btree (require_erp_reference) 
TABLESPACE pg_default
WHERE (require_erp_reference = true);

COMMIT;