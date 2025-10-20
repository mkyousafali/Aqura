-- Migration: Create quick_task_assignments table
-- File: 23_quick_task_assignments.sql
-- Description: Creates the quick_task_assignments table for managing quick task assignments to users

BEGIN;

-- Create trigger functions for quick task assignments
CREATE OR REPLACE FUNCTION copy_completion_requirements_to_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_quick_task_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_quick_task_status()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create quick_task_assignments table
CREATE TABLE public.quick_task_assignments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  quick_task_id uuid NOT NULL,
  assigned_to_user_id uuid NOT NULL,
  status character varying(50) NULL DEFAULT 'pending'::character varying,
  accepted_at timestamp with time zone NULL,
  started_at timestamp with time zone NULL,
  completed_at timestamp with time zone NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  require_task_finished boolean NULL DEFAULT true,
  require_photo_upload boolean NULL DEFAULT false,
  require_erp_reference boolean NULL DEFAULT false,
  CONSTRAINT quick_task_assignments_pkey PRIMARY KEY (id),
  CONSTRAINT quick_task_assignments_quick_task_id_assigned_to_user_id_key UNIQUE (quick_task_id, assigned_to_user_id),
  CONSTRAINT quick_task_assignments_assigned_to_user_id_fkey FOREIGN KEY (assigned_to_user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT quick_task_assignments_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES quick_tasks (id) ON DELETE CASCADE,
  CONSTRAINT chk_require_task_finished_not_null CHECK ((require_task_finished IS NOT NULL))
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_task 
ON public.quick_task_assignments USING btree (quick_task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_user 
ON public.quick_task_assignments USING btree (assigned_to_user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_status 
ON public.quick_task_assignments USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_created_at 
ON public.quick_task_assignments USING btree (created_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_require_task_finished 
ON public.quick_task_assignments USING btree (require_task_finished) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_require_photo_upload 
ON public.quick_task_assignments USING btree (require_photo_upload) 
TABLESPACE pg_default
WHERE (require_photo_upload = true);

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_require_erp_reference 
ON public.quick_task_assignments USING btree (require_erp_reference) 
TABLESPACE pg_default
WHERE (require_erp_reference = true);

-- Create triggers
CREATE TRIGGER trigger_copy_completion_requirements
AFTER INSERT ON quick_task_assignments 
FOR EACH ROW
EXECUTE FUNCTION copy_completion_requirements_to_assignment();

CREATE TRIGGER trigger_create_quick_task_notification
AFTER INSERT ON quick_task_assignments 
FOR EACH ROW
EXECUTE FUNCTION create_quick_task_notification();

CREATE TRIGGER trigger_update_quick_task_status
AFTER UPDATE ON quick_task_assignments 
FOR EACH ROW
EXECUTE FUNCTION update_quick_task_status();

COMMIT;