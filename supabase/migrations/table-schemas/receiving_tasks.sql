-- ================================================================
-- TABLE SCHEMA: receiving_tasks
-- Generated: 2025-11-06T11:09:39.020Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.receiving_tasks (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    receiving_record_id uuid NOT NULL,
    role_type character varying NOT NULL,
    assigned_user_id uuid,
    requires_erp_reference boolean DEFAULT false,
    requires_original_bill_upload boolean DEFAULT false,
    requires_reassignment boolean DEFAULT false,
    requires_task_finished_mark boolean DEFAULT true,
    erp_reference_number character varying,
    original_bill_uploaded boolean DEFAULT false,
    original_bill_file_path text,
    task_completed boolean DEFAULT false,
    completed_at timestamp with time zone,
    clearance_certificate_url text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone NOT NULL DEFAULT now(),
    template_id uuid,
    task_status character varying NOT NULL DEFAULT 'pending'::character varying,
    title text,
    description text,
    priority character varying DEFAULT 'high'::character varying,
    due_date timestamp with time zone,
    completed_by_user_id uuid,
    completion_photo_url text,
    completion_notes text,
    rule_effective_date timestamp with time zone
);

-- Table comment
COMMENT ON TABLE public.receiving_tasks IS 'Table for receiving tasks management';

-- Column comments
COMMENT ON COLUMN public.receiving_tasks.id IS 'Primary key identifier';
COMMENT ON COLUMN public.receiving_tasks.receiving_record_id IS 'Foreign key reference to receiving_record table';
COMMENT ON COLUMN public.receiving_tasks.role_type IS 'role type field';
COMMENT ON COLUMN public.receiving_tasks.assigned_user_id IS 'Foreign key reference to assigned_user table';
COMMENT ON COLUMN public.receiving_tasks.requires_erp_reference IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_tasks.requires_original_bill_upload IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_tasks.requires_reassignment IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_tasks.requires_task_finished_mark IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_tasks.erp_reference_number IS 'Reference number';
COMMENT ON COLUMN public.receiving_tasks.original_bill_uploaded IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_tasks.original_bill_file_path IS 'original bill file path field';
COMMENT ON COLUMN public.receiving_tasks.task_completed IS 'Boolean flag';
COMMENT ON COLUMN public.receiving_tasks.completed_at IS 'completed at field';
COMMENT ON COLUMN public.receiving_tasks.clearance_certificate_url IS 'URL or file path';
COMMENT ON COLUMN public.receiving_tasks.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.receiving_tasks.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.receiving_tasks.template_id IS 'Foreign key reference to template table';
COMMENT ON COLUMN public.receiving_tasks.task_status IS 'Status indicator';
COMMENT ON COLUMN public.receiving_tasks.title IS 'title field';
COMMENT ON COLUMN public.receiving_tasks.description IS 'description field';
COMMENT ON COLUMN public.receiving_tasks.priority IS 'priority field';
COMMENT ON COLUMN public.receiving_tasks.due_date IS 'Date field';
COMMENT ON COLUMN public.receiving_tasks.completed_by_user_id IS 'Foreign key reference to completed_by_user table';
COMMENT ON COLUMN public.receiving_tasks.completion_photo_url IS 'URL or file path';
COMMENT ON COLUMN public.receiving_tasks.completion_notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.receiving_tasks.rule_effective_date IS 'Date field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS receiving_tasks_pkey ON public.receiving_tasks USING btree (id);

-- Foreign key index for receiving_record_id
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_receiving_record_id ON public.receiving_tasks USING btree (receiving_record_id);

-- Foreign key index for assigned_user_id
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_assigned_user_id ON public.receiving_tasks USING btree (assigned_user_id);

-- Foreign key index for template_id
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_template_id ON public.receiving_tasks USING btree (template_id);

-- Foreign key index for completed_by_user_id
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_completed_by_user_id ON public.receiving_tasks USING btree (completed_by_user_id);

-- Date index for completed_at
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_completed_at ON public.receiving_tasks USING btree (completed_at);

-- Date index for due_date
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_due_date ON public.receiving_tasks USING btree (due_date);

-- Date index for rule_effective_date
CREATE INDEX IF NOT EXISTS idx_receiving_tasks_rule_effective_date ON public.receiving_tasks USING btree (rule_effective_date);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for receiving_tasks

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.receiving_tasks ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "receiving_tasks_select_policy" ON public.receiving_tasks
    FOR SELECT USING (true);

CREATE POLICY "receiving_tasks_insert_policy" ON public.receiving_tasks
    FOR INSERT WITH CHECK (true);

CREATE POLICY "receiving_tasks_update_policy" ON public.receiving_tasks
    FOR UPDATE USING (true);

CREATE POLICY "receiving_tasks_delete_policy" ON public.receiving_tasks
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for receiving_tasks

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.receiving_tasks (receiving_record_id, role_type, assigned_user_id)
VALUES ('uuid-example', 'example', 'uuid-example');
*/

-- Select example
/*
SELECT * FROM public.receiving_tasks 
WHERE receiving_record_id = $1;
*/

-- Update example
/*
UPDATE public.receiving_tasks 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF RECEIVING_TASKS SCHEMA
-- ================================================================
