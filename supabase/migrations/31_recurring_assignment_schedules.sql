-- Migration: Create recurring_assignment_schedules table
-- File: 31_recurring_assignment_schedules.sql
-- Description: Creates the recurring_assignment_schedules table for managing recurring task assignment schedules

BEGIN;

-- Create recurring_assignment_schedules table
CREATE TABLE public.recurring_assignment_schedules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  assignment_id uuid NOT NULL,
  repeat_type text NOT NULL,
  repeat_interval integer NOT NULL DEFAULT 1,
  repeat_on_days integer[] NULL,
  repeat_on_date integer NULL,
  repeat_on_month integer NULL,
  execute_time time without time zone NOT NULL DEFAULT '09:00:00'::time without time zone,
  timezone text NULL DEFAULT 'UTC'::text,
  start_date date NOT NULL,
  end_date date NULL,
  max_occurrences integer NULL,
  is_active boolean NULL DEFAULT true,
  last_executed_at timestamp with time zone NULL,
  next_execution_at timestamp with time zone NOT NULL,
  executions_count integer NULL DEFAULT 0,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  created_by text NOT NULL,
  CONSTRAINT recurring_assignment_schedules_pkey PRIMARY KEY (id),
  CONSTRAINT fk_recurring_schedules_assignment FOREIGN KEY (assignment_id) REFERENCES task_assignments (id) ON DELETE CASCADE,
  CONSTRAINT chk_repeat_interval_positive CHECK ((repeat_interval > 0)),
  CONSTRAINT chk_max_occurrences_positive CHECK (
    (
      (max_occurrences IS NULL)
      OR (max_occurrences > 0)
    )
  ),
  CONSTRAINT recurring_assignment_schedules_repeat_type_check CHECK (
    (
      repeat_type = ANY (
        ARRAY[
          'daily'::text,
          'weekly'::text,
          'monthly'::text,
          'yearly'::text,
          'custom'::text
        ]
      )
    )
  ),
  CONSTRAINT chk_schedule_bounds CHECK (
    (
      (end_date IS NULL)
      OR (end_date >= start_date)
    )
  ),
  CONSTRAINT chk_next_execution_after_start CHECK (((next_execution_at)::date >= start_date))
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_recurring_schedules_assignment_id 
ON public.recurring_assignment_schedules USING btree (assignment_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_next_execution 
ON public.recurring_assignment_schedules USING btree (next_execution_at, is_active) 
TABLESPACE pg_default
WHERE (is_active = true);

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_active 
ON public.recurring_assignment_schedules USING btree (is_active, repeat_type) 
TABLESPACE pg_default;

COMMIT;