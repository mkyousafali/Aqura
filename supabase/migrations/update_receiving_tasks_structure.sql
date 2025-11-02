-- =====================================================
-- UPDATE RECEIVING_TASKS TABLE STRUCTURE
-- =====================================================
-- Purpose: Modify receiving_tasks for full separation from general task system
-- Changes:
--   1. Add template_id column (FK to receiving_task_templates)
--   2. Add task_status column (pending, in_progress, completed, etc.)
--   3. Remove task_id column (no longer needed)
--   4. Remove assignment_id column (no longer needed)
--   5. Keep all other receiving-specific fields
-- =====================================================

-- =====================================================
-- STEP 1: ADD NEW COLUMNS
-- =====================================================

-- Add template_id column
ALTER TABLE public.receiving_tasks 
  ADD COLUMN IF NOT EXISTS template_id UUID NULL;

-- Add title column (populated from template)
ALTER TABLE public.receiving_tasks 
  ADD COLUMN IF NOT EXISTS title TEXT NULL;

-- Add description column (populated from template)
ALTER TABLE public.receiving_tasks 
  ADD COLUMN IF NOT EXISTS description TEXT NULL;

-- Add priority column (copied from template)
ALTER TABLE public.receiving_tasks 
  ADD COLUMN IF NOT EXISTS priority VARCHAR(20) NULL DEFAULT 'high';

-- Add due_date column
ALTER TABLE public.receiving_tasks 
  ADD COLUMN IF NOT EXISTS due_date TIMESTAMP WITH TIME ZONE NULL;

-- Add completed_by_user_id column
ALTER TABLE public.receiving_tasks 
  ADD COLUMN IF NOT EXISTS completed_by_user_id UUID NULL;

-- Add task_status column
ALTER TABLE public.receiving_tasks 
  ADD COLUMN IF NOT EXISTS task_status VARCHAR(50) NOT NULL DEFAULT 'pending';

-- Add constraint for task_status (drop first if exists)
ALTER TABLE public.receiving_tasks 
  DROP CONSTRAINT IF EXISTS receiving_tasks_task_status_check;

ALTER TABLE public.receiving_tasks 
  ADD CONSTRAINT receiving_tasks_task_status_check 
  CHECK (task_status IN ('pending', 'in_progress', 'completed', 'cancelled'));

-- =====================================================
-- STEP 2: ADD FOREIGN KEY TO TEMPLATES
-- =====================================================

-- Drop the constraint first if it exists
ALTER TABLE public.receiving_tasks 
  DROP CONSTRAINT IF EXISTS receiving_tasks_template_id_fkey;

ALTER TABLE public.receiving_tasks 
  ADD CONSTRAINT receiving_tasks_template_id_fkey 
  FOREIGN KEY (template_id) 
  REFERENCES receiving_task_templates(id) 
  ON DELETE SET NULL;

-- =====================================================
-- STEP 3: REMOVE OLD COLUMNS (task_id, assignment_id)
-- =====================================================

-- First, drop the foreign key constraints
ALTER TABLE public.receiving_tasks 
  DROP CONSTRAINT IF EXISTS receiving_tasks_task_id_fkey CASCADE;

ALTER TABLE public.receiving_tasks 
  DROP CONSTRAINT IF EXISTS receiving_tasks_assignment_id_fkey CASCADE;

-- Drop the indexes on these columns
DROP INDEX IF EXISTS idx_receiving_tasks_task_id;
DROP INDEX IF EXISTS idx_receiving_tasks_assignment_id;

-- Now drop the columns
ALTER TABLE public.receiving_tasks 
  DROP COLUMN IF EXISTS task_id CASCADE;

ALTER TABLE public.receiving_tasks 
  DROP COLUMN IF EXISTS assignment_id CASCADE;

-- =====================================================
-- STEP 4: ADD NEW INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_template_id 
  ON public.receiving_tasks USING btree (template_id) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_task_status 
  ON public.receiving_tasks USING btree (task_status) 
  TABLESPACE pg_default;

-- Composite index for common queries
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_status_role 
  ON public.receiving_tasks USING btree (task_status, role_type) 
  TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_receiving_tasks_user_status 
  ON public.receiving_tasks USING btree (assigned_user_id, task_status) 
  TABLESPACE pg_default;

-- =====================================================
-- STEP 5: UPDATE COMMENTS
-- =====================================================

COMMENT ON TABLE public.receiving_tasks IS 
  'Receiving-specific tasks with full separation from general task system. Links templates with receiving records.';

COMMENT ON COLUMN public.receiving_tasks.template_id IS 
  'Foreign key to receiving_task_templates. Defines the task type and role.';

COMMENT ON COLUMN public.receiving_tasks.task_status IS 
  'Current status: pending, in_progress, completed, cancelled';

COMMENT ON COLUMN public.receiving_tasks.role_type IS 
  'Role type for this task: branch_manager, purchase_manager, inventory_manager, night_supervisor, warehouse_handler, shelf_stocker, accountant';

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
  has_template_id BOOLEAN;
  has_task_status BOOLEAN;
  has_task_id BOOLEAN;
  has_assignment_id BOOLEAN;
BEGIN
  -- Check if new columns exist
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receiving_tasks' 
    AND column_name = 'template_id'
  ) INTO has_template_id;
  
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receiving_tasks' 
    AND column_name = 'task_status'
  ) INTO has_task_status;
  
  -- Check if old columns are removed
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receiving_tasks' 
    AND column_name = 'task_id'
  ) INTO has_task_id;
  
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'receiving_tasks' 
    AND column_name = 'assignment_id'
  ) INTO has_assignment_id;
  
  -- Report results
  IF has_template_id AND has_task_status THEN
    RAISE NOTICE '✅ New columns added: template_id, task_status';
  ELSE
    RAISE EXCEPTION '❌ Failed to add new columns';
  END IF;
  
  IF NOT has_task_id AND NOT has_assignment_id THEN
    RAISE NOTICE '✅ Old columns removed: task_id, assignment_id';
  ELSE
    RAISE EXCEPTION '❌ Old columns still exist';
  END IF;
  
  RAISE NOTICE '✅ receiving_tasks table structure updated successfully';
END $$;
