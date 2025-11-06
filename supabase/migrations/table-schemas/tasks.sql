-- ================================================================
-- TABLE SCHEMA: tasks
-- Generated: 2025-11-06T11:09:39.023Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.tasks (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    title text NOT NULL,
    description text,
    require_task_finished boolean DEFAULT false,
    require_photo_upload boolean DEFAULT false,
    require_erp_reference boolean DEFAULT false,
    can_escalate boolean DEFAULT false,
    can_reassign boolean DEFAULT false,
    created_by text NOT NULL,
    created_by_name text,
    created_by_role text,
    status text DEFAULT 'draft'::text,
    priority text DEFAULT 'medium'::text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deleted_at timestamp with time zone,
    due_date date,
    due_time time without time zone,
    due_datetime timestamp with time zone,
    search_vector tsvector,
    metadata jsonb
);

-- Table comment
COMMENT ON TABLE public.tasks IS 'Table for tasks management';

-- Column comments
COMMENT ON COLUMN public.tasks.id IS 'Primary key identifier';
COMMENT ON COLUMN public.tasks.title IS 'title field';
COMMENT ON COLUMN public.tasks.description IS 'description field';
COMMENT ON COLUMN public.tasks.require_task_finished IS 'Boolean flag';
COMMENT ON COLUMN public.tasks.require_photo_upload IS 'Boolean flag';
COMMENT ON COLUMN public.tasks.require_erp_reference IS 'Boolean flag';
COMMENT ON COLUMN public.tasks.can_escalate IS 'Boolean flag';
COMMENT ON COLUMN public.tasks.can_reassign IS 'Boolean flag';
COMMENT ON COLUMN public.tasks.created_by IS 'created by field';
COMMENT ON COLUMN public.tasks.created_by_name IS 'Name field';
COMMENT ON COLUMN public.tasks.created_by_role IS 'created by role field';
COMMENT ON COLUMN public.tasks.status IS 'Status indicator';
COMMENT ON COLUMN public.tasks.priority IS 'priority field';
COMMENT ON COLUMN public.tasks.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.tasks.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.tasks.deleted_at IS 'deleted at field';
COMMENT ON COLUMN public.tasks.due_date IS 'Date field';
COMMENT ON COLUMN public.tasks.due_time IS 'due time field';
COMMENT ON COLUMN public.tasks.due_datetime IS 'Date field';
COMMENT ON COLUMN public.tasks.search_vector IS 'search vector field';
COMMENT ON COLUMN public.tasks.metadata IS 'JSON data structure';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS tasks_pkey ON public.tasks USING btree (id);

-- Date index for deleted_at
CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at ON public.tasks USING btree (deleted_at);

-- Date index for due_date
CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON public.tasks USING btree (due_date);

-- Date index for due_datetime
CREATE INDEX IF NOT EXISTS idx_tasks_due_datetime ON public.tasks USING btree (due_datetime);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for tasks

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "tasks_select_policy" ON public.tasks
    FOR SELECT USING (true);

CREATE POLICY "tasks_insert_policy" ON public.tasks
    FOR INSERT WITH CHECK (true);

CREATE POLICY "tasks_update_policy" ON public.tasks
    FOR UPDATE USING (true);

CREATE POLICY "tasks_delete_policy" ON public.tasks
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for tasks

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.tasks (title, description, require_task_finished)
VALUES ('example text', 'example text', true);
*/

-- Select example
/*
SELECT * FROM public.tasks 
WHERE id = $1;
*/

-- Update example
/*
UPDATE public.tasks 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF TASKS SCHEMA
-- ================================================================
