-- Migration: Create quick_task_user_preferences table
-- File: 27_quick_task_user_preferences.sql
-- Description: Creates the quick_task_user_preferences table for managing user preferences for quick task creation

BEGIN;

-- Create quick_task_user_preferences table
CREATE TABLE public.quick_task_user_preferences (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  default_branch_id bigint NULL,
  default_price_tag character varying(50) NULL,
  default_issue_type character varying(100) NULL,
  default_priority character varying(50) NULL,
  selected_user_ids uuid[] NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT quick_task_user_preferences_pkey PRIMARY KEY (id),
  CONSTRAINT quick_task_user_preferences_user_id_key UNIQUE (user_id),
  CONSTRAINT quick_task_user_preferences_default_branch_id_fkey FOREIGN KEY (default_branch_id) REFERENCES branches (id) ON DELETE SET NULL,
  CONSTRAINT quick_task_user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_user 
ON public.quick_task_user_preferences USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_user_preferences_branch 
ON public.quick_task_user_preferences USING btree (default_branch_id) 
TABLESPACE pg_default;

COMMIT;