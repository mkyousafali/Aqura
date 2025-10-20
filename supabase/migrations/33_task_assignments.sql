-- Migration: Create task_assignments table
-- File: 33_task_assignments.sql
-- Description: Creates the task_assignments table for managing task assignments to users and branches

BEGIN;

-- Create task_assignments table
CREATE TABLE public.task_assignments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL,
  assignment_type text NOT NULL,
  assigned_to_user_id text NULL,
  assigned_to_branch_id uuid NULL,
  assigned_by text NOT NULL,
  assigned_by_name text NULL,
  assigned_at timestamp with time zone NULL DEFAULT now(),
  status text NULL DEFAULT 'assigned'::text,
  started_at timestamp with time zone NULL,
  completed_at timestamp with time zone NULL,
  schedule_date date NULL,
  schedule_time time without time zone NULL,
  deadline_date date NULL,
  deadline_time time without time zone NULL,
  deadline_datetime timestamp with time zone NULL,
  is_reassignable boolean NULL DEFAULT true,
  is_recurring boolean NULL DEFAULT false,
  recurring_pattern jsonb NULL,
  notes text NULL,
  priority_override text NULL,
  require_task_finished boolean NULL DEFAULT true,
  require_photo_upload boolean NULL DEFAULT false,
  require_erp_reference boolean NULL DEFAULT false,
  reassigned_from uuid NULL,
  reassignment_reason text NULL,
  reassigned_at timestamp with time zone NULL,
  CONSTRAINT task_assignments_pkey PRIMARY KEY (id),
  CONSTRAINT task_assignments_task_id_assignment_type_assigned_to_user_i_key UNIQUE (
    task_id,
    assignment_type,
    assigned_to_user_id,
    assigned_to_branch_id
  ),
  CONSTRAINT fk_task_assignments_reassigned_from FOREIGN KEY (reassigned_from) REFERENCES task_assignments (id) ON DELETE SET NULL,
  CONSTRAINT task_assignments_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
  CONSTRAINT chk_schedule_consistency CHECK (
    (
      (schedule_date IS NULL AND schedule_time IS NULL)
      OR (schedule_date IS NOT NULL)
    )
  ),
  CONSTRAINT chk_priority_override_valid CHECK (
    (priority_override IS NULL)
    OR (
      priority_override = ANY (
        ARRAY[
          'low'::text,
          'medium'::text,
          'high'::text,
          'urgent'::text
        ]
      )
    )
  ),
  CONSTRAINT chk_deadline_consistency CHECK (
    (
      (deadline_date IS NULL AND deadline_time IS NULL)
      OR (deadline_date IS NOT NULL)
    )
  )
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_task_assignments_task_id 
ON public.task_assignments USING btree (task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_user_id 
ON public.task_assignments USING btree (assigned_to_user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_branch_id 
ON public.task_assignments USING btree (assigned_to_branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assignment_type 
ON public.task_assignments USING btree (assignment_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_status 
ON public.task_assignments USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_by 
ON public.task_assignments USING btree (assigned_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_deadline_datetime 
ON public.task_assignments USING btree (deadline_datetime) 
TABLESPACE pg_default
WHERE (deadline_datetime IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_task_assignments_schedule_date 
ON public.task_assignments USING btree (schedule_date) 
TABLESPACE pg_default
WHERE (schedule_date IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_task_assignments_recurring 
ON public.task_assignments USING btree (is_recurring, status) 
TABLESPACE pg_default
WHERE (is_recurring = true);

CREATE INDEX IF NOT EXISTS idx_task_assignments_reassignable 
ON public.task_assignments USING btree (is_reassignable, status) 
TABLESPACE pg_default
WHERE (is_reassignable = true);

CREATE INDEX IF NOT EXISTS idx_task_assignments_overdue 
ON public.task_assignments USING btree (deadline_datetime, status) 
TABLESPACE pg_default
WHERE (
  (deadline_datetime IS NOT NULL)
  AND (
    status <> ALL (ARRAY['completed'::text, 'cancelled'::text])
  )
);

-- Create triggers
CREATE TRIGGER cleanup_assignment_notifications_trigger
AFTER DELETE ON task_assignments 
FOR EACH ROW
EXECUTE FUNCTION trigger_cleanup_assignment_notifications();

CREATE TRIGGER trigger_update_deadline_datetime 
BEFORE INSERT OR UPDATE OF deadline_date, deadline_time 
ON task_assignments 
FOR EACH ROW
EXECUTE FUNCTION update_deadline_datetime();

COMMIT;