-- Migration: Add foreign key constraint for task_assignments.assigned_to_branch_id
-- File: 76_add_task_assignments_branch_fkey.sql
-- Description: Fixes type mismatch and adds foreign key constraint between task_assignments and branches tables

BEGIN;

-- First, alter the column type from uuid to bigint to match branches.id
-- This will fail if there are non-null uuid values that can't be converted
-- We'll set existing values to NULL first if needed
UPDATE public.task_assignments
SET assigned_to_branch_id = NULL
WHERE assigned_to_branch_id IS NOT NULL;

-- Now alter the column type from uuid to bigint
ALTER TABLE public.task_assignments
ALTER COLUMN assigned_to_branch_id TYPE bigint USING NULL;

-- Add foreign key constraint for assigned_to_branch_id
ALTER TABLE public.task_assignments
ADD CONSTRAINT task_assignments_assigned_to_branch_id_fkey 
FOREIGN KEY (assigned_to_branch_id) 
REFERENCES public.branches (id) 
ON DELETE SET NULL;

-- Add comment to document the relationship
COMMENT ON CONSTRAINT task_assignments_assigned_to_branch_id_fkey ON public.task_assignments IS 
'Foreign key relationship to branches table for branch assignments';

COMMIT;
