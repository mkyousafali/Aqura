-- Migration: Add foreign key constraints for user relationships in task_assignments
-- File: 78_add_user_foreign_keys.sql
-- Description: Converts text columns to uuid and adds FK constraints to link assigned_by and assigned_to_user_id to users table
-- Note: quick_tasks and quick_task_assignments already have proper uuid FK constraints from migrations 23 and 28

BEGIN;

-- ============================================================================
-- TASK_ASSIGNMENTS: Convert assigned_by from text to uuid
-- ============================================================================

-- Step 1: Convert task_assignments.assigned_by from text to uuid
ALTER TABLE public.task_assignments
ALTER COLUMN assigned_by TYPE uuid USING assigned_by::uuid;

-- Step 2: Add foreign key constraint for task_assignments.assigned_by
ALTER TABLE public.task_assignments
ADD CONSTRAINT task_assignments_assigned_by_fkey 
FOREIGN KEY (assigned_by) 
REFERENCES public.users(id) 
ON DELETE SET NULL;

-- ============================================================================
-- TASK_ASSIGNMENTS: Convert assigned_to_user_id from text to uuid
-- ============================================================================

-- Step 3: Convert task_assignments.assigned_to_user_id from text to uuid
ALTER TABLE public.task_assignments
ALTER COLUMN assigned_to_user_id TYPE uuid USING assigned_to_user_id::uuid;

-- Step 4: Add foreign key constraint for task_assignments.assigned_to_user_id  
ALTER TABLE public.task_assignments
ADD CONSTRAINT task_assignments_assigned_to_user_id_fkey 
FOREIGN KEY (assigned_to_user_id) 
REFERENCES public.users(id) 
ON DELETE SET NULL;

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- The following already have proper FK constraints:
-- - quick_tasks.assigned_by (uuid) -> users(id) from migration 28
-- - quick_task_assignments.assigned_to_user_id (uuid) -> users(id) from migration 23
-- No changes needed for quick_task tables

COMMIT;
