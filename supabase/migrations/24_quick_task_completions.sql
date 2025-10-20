-- Migration: Create quick_task_completions table
-- File: 24_quick_task_completions.sql
-- Description: Creates the quick_task_completions table for managing quick task completion records

BEGIN;

-- Create trigger function for quick task completions
CREATE OR REPLACE FUNCTION update_quick_task_completions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create quick_task_completions table
CREATE TABLE public.quick_task_completions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  quick_task_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  completed_by_user_id uuid NOT NULL,
  completion_notes text NULL,
  photo_path text NULL,
  erp_reference character varying(255) NULL,
  completion_status character varying(50) NOT NULL DEFAULT 'submitted'::character varying,
  verified_by_user_id uuid NULL,
  verified_at timestamp with time zone NULL,
  verification_notes text NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT quick_task_completions_pkey PRIMARY KEY (id),
  CONSTRAINT quick_task_completions_assignment_unique UNIQUE (assignment_id),
  CONSTRAINT quick_task_completions_completed_by_user_id_fkey FOREIGN KEY (completed_by_user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT quick_task_completions_verified_by_user_id_fkey FOREIGN KEY (verified_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT quick_task_completions_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES quick_task_assignments (id) ON DELETE CASCADE,
  CONSTRAINT quick_task_completions_quick_task_id_fkey FOREIGN KEY (quick_task_id) REFERENCES quick_tasks (id) ON DELETE CASCADE,
  CONSTRAINT chk_completion_status_valid CHECK (
    (
      (completion_status)::text = ANY (
        (
          ARRAY[
            'submitted'::character varying,
            'verified'::character varying,
            'rejected'::character varying,
            'pending_review'::character varying
          ]
        )::text[]
      )
    )
  ),
  CONSTRAINT chk_verified_at_when_verified CHECK (
    (
      (
        ((completion_status)::text <> 'verified'::text)
        AND (verified_at IS NULL)
      )
      OR (
        ((completion_status)::text = 'verified'::text)
        AND (verified_at IS NOT NULL)
      )
    )
  )
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_task 
ON public.quick_task_completions USING btree (quick_task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_completions_assignment 
ON public.quick_task_completions USING btree (assignment_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_completions_completed_by 
ON public.quick_task_completions USING btree (completed_by_user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_completions_status 
ON public.quick_task_completions USING btree (completion_status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_completions_created_at 
ON public.quick_task_completions USING btree (created_at DESC) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_completions_verified_by 
ON public.quick_task_completions USING btree (verified_by_user_id) 
TABLESPACE pg_default
WHERE (verified_by_user_id IS NOT NULL);

-- Create trigger
CREATE TRIGGER trigger_update_quick_task_completions_updated_at 
BEFORE UPDATE ON quick_task_completions 
FOR EACH ROW
EXECUTE FUNCTION update_quick_task_completions_updated_at();

COMMIT;