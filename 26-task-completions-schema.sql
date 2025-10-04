-- Task Completions Schema
-- This table tracks task completion details with verification and requirement tracking

CREATE TABLE public.task_completions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL,
  assignment_id uuid NOT NULL,
  completed_by text NOT NULL,
  completed_by_name text NULL,
  completed_by_branch_id uuid NULL,
  task_finished_completed boolean NULL DEFAULT false,
  photo_uploaded_completed boolean NULL DEFAULT false,
  erp_reference_completed boolean NULL DEFAULT false,
  erp_reference_number text NULL,
  completion_notes text NULL,
  verified_by text NULL,
  verified_at timestamp with time zone NULL,
  verification_notes text NULL,
  completed_at timestamp with time zone NULL DEFAULT now(),
  created_at timestamp with time zone NULL DEFAULT now(),
  completion_photo_url text NULL,
  CONSTRAINT task_completions_pkey PRIMARY KEY (id),
  CONSTRAINT task_completions_assignment_id_fkey FOREIGN KEY (assignment_id) REFERENCES task_assignments (id) ON DELETE CASCADE,
  CONSTRAINT task_completions_task_id_fkey FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
  CONSTRAINT chk_photo_url_consistency CHECK (
    (photo_uploaded_completed = false)
    OR (completion_photo_url IS NOT NULL)
  )
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_task_completions_task_id ON public.task_completions USING btree (task_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_assignment_id ON public.task_completions USING btree (assignment_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_completed_by ON public.task_completions USING btree (completed_by) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_completed_by_branch_id ON public.task_completions USING btree (completed_by_branch_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_task_finished ON public.task_completions USING btree (task_finished_completed) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_photo_uploaded ON public.task_completions USING btree (photo_uploaded_completed) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_erp_reference ON public.task_completions USING btree (erp_reference_completed) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_completed_at ON public.task_completions USING btree (completed_at DESC) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_photo_url ON public.task_completions USING btree (completion_photo_url) TABLESPACE pg_default
WHERE (completion_photo_url IS NOT NULL);