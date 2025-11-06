-- ================================================================
-- TABLE SCHEMA: employee_warnings
-- Generated: 2025-11-06T11:09:39.007Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.employee_warnings (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    user_id uuid,
    employee_id uuid,
    username character varying,
    warning_type character varying NOT NULL,
    has_fine boolean DEFAULT false,
    fine_amount numeric DEFAULT NULL::numeric,
    fine_currency character varying DEFAULT 'USD'::character varying,
    fine_status character varying DEFAULT 'pending'::character varying,
    fine_due_date date,
    fine_paid_date timestamp without time zone,
    fine_paid_amount numeric DEFAULT NULL::numeric,
    warning_text text NOT NULL,
    language_code character varying NOT NULL DEFAULT 'en'::character varying,
    task_id uuid,
    task_title character varying,
    task_description text,
    assignment_id uuid,
    total_tasks_assigned integer DEFAULT 0,
    total_tasks_completed integer DEFAULT 0,
    total_tasks_overdue integer DEFAULT 0,
    completion_rate numeric DEFAULT 0,
    issued_by uuid,
    issued_by_username character varying,
    issued_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    warning_status character varying DEFAULT 'active'::character varying,
    acknowledged_at timestamp without time zone,
    acknowledged_by uuid,
    resolved_at timestamp without time zone,
    resolved_by uuid,
    resolution_notes text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    branch_id bigint,
    department_id uuid,
    severity_level character varying DEFAULT 'medium'::character varying,
    follow_up_required boolean DEFAULT false,
    follow_up_date date,
    warning_reference character varying,
    warning_document_url text,
    is_deleted boolean DEFAULT false,
    deleted_at timestamp without time zone,
    deleted_by uuid,
    fine_paid_at timestamp without time zone,
    frontend_save_id character varying,
    fine_payment_note text,
    fine_payment_method character varying DEFAULT 'cash'::character varying,
    fine_payment_reference character varying
);

-- Table comment
COMMENT ON TABLE public.employee_warnings IS 'Table for employee warnings management';

-- Column comments
COMMENT ON COLUMN public.employee_warnings.id IS 'Primary key identifier';
COMMENT ON COLUMN public.employee_warnings.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.employee_warnings.employee_id IS 'Foreign key reference to employee table';
COMMENT ON COLUMN public.employee_warnings.username IS 'Name field';
COMMENT ON COLUMN public.employee_warnings.warning_type IS 'warning type field';
COMMENT ON COLUMN public.employee_warnings.has_fine IS 'Boolean flag';
COMMENT ON COLUMN public.employee_warnings.fine_amount IS 'Monetary amount';
COMMENT ON COLUMN public.employee_warnings.fine_currency IS 'fine currency field';
COMMENT ON COLUMN public.employee_warnings.fine_status IS 'Status indicator';
COMMENT ON COLUMN public.employee_warnings.fine_due_date IS 'Date field';
COMMENT ON COLUMN public.employee_warnings.fine_paid_date IS 'Date field';
COMMENT ON COLUMN public.employee_warnings.fine_paid_amount IS 'Monetary amount';
COMMENT ON COLUMN public.employee_warnings.warning_text IS 'warning text field';
COMMENT ON COLUMN public.employee_warnings.language_code IS 'language code field';
COMMENT ON COLUMN public.employee_warnings.task_id IS 'Foreign key reference to task table';
COMMENT ON COLUMN public.employee_warnings.task_title IS 'task title field';
COMMENT ON COLUMN public.employee_warnings.task_description IS 'task description field';
COMMENT ON COLUMN public.employee_warnings.assignment_id IS 'Foreign key reference to assignment table';
COMMENT ON COLUMN public.employee_warnings.total_tasks_assigned IS 'total tasks assigned field';
COMMENT ON COLUMN public.employee_warnings.total_tasks_completed IS 'total tasks completed field';
COMMENT ON COLUMN public.employee_warnings.total_tasks_overdue IS 'total tasks overdue field';
COMMENT ON COLUMN public.employee_warnings.completion_rate IS 'completion rate field';
COMMENT ON COLUMN public.employee_warnings.issued_by IS 'issued by field';
COMMENT ON COLUMN public.employee_warnings.issued_by_username IS 'Name field';
COMMENT ON COLUMN public.employee_warnings.issued_at IS 'issued at field';
COMMENT ON COLUMN public.employee_warnings.warning_status IS 'Status indicator';
COMMENT ON COLUMN public.employee_warnings.acknowledged_at IS 'acknowledged at field';
COMMENT ON COLUMN public.employee_warnings.acknowledged_by IS 'acknowledged by field';
COMMENT ON COLUMN public.employee_warnings.resolved_at IS 'resolved at field';
COMMENT ON COLUMN public.employee_warnings.resolved_by IS 'resolved by field';
COMMENT ON COLUMN public.employee_warnings.resolution_notes IS 'Additional notes or comments';
COMMENT ON COLUMN public.employee_warnings.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.employee_warnings.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.employee_warnings.branch_id IS 'Foreign key reference to branch table';
COMMENT ON COLUMN public.employee_warnings.department_id IS 'Foreign key reference to department table';
COMMENT ON COLUMN public.employee_warnings.severity_level IS 'severity level field';
COMMENT ON COLUMN public.employee_warnings.follow_up_required IS 'Boolean flag';
COMMENT ON COLUMN public.employee_warnings.follow_up_date IS 'Date field';
COMMENT ON COLUMN public.employee_warnings.warning_reference IS 'warning reference field';
COMMENT ON COLUMN public.employee_warnings.warning_document_url IS 'URL or file path';
COMMENT ON COLUMN public.employee_warnings.is_deleted IS 'Boolean flag';
COMMENT ON COLUMN public.employee_warnings.deleted_at IS 'deleted at field';
COMMENT ON COLUMN public.employee_warnings.deleted_by IS 'deleted by field';
COMMENT ON COLUMN public.employee_warnings.fine_paid_at IS 'fine paid at field';
COMMENT ON COLUMN public.employee_warnings.frontend_save_id IS 'Foreign key reference to frontend_save table';
COMMENT ON COLUMN public.employee_warnings.fine_payment_note IS 'fine payment note field';
COMMENT ON COLUMN public.employee_warnings.fine_payment_method IS 'fine payment method field';
COMMENT ON COLUMN public.employee_warnings.fine_payment_reference IS 'fine payment reference field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS employee_warnings_pkey ON public.employee_warnings USING btree (id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_employee_warnings_user_id ON public.employee_warnings USING btree (user_id);

-- Foreign key index for employee_id
CREATE INDEX IF NOT EXISTS idx_employee_warnings_employee_id ON public.employee_warnings USING btree (employee_id);

-- Foreign key index for task_id
CREATE INDEX IF NOT EXISTS idx_employee_warnings_task_id ON public.employee_warnings USING btree (task_id);

-- Foreign key index for assignment_id
CREATE INDEX IF NOT EXISTS idx_employee_warnings_assignment_id ON public.employee_warnings USING btree (assignment_id);

-- Foreign key index for branch_id
CREATE INDEX IF NOT EXISTS idx_employee_warnings_branch_id ON public.employee_warnings USING btree (branch_id);

-- Foreign key index for department_id
CREATE INDEX IF NOT EXISTS idx_employee_warnings_department_id ON public.employee_warnings USING btree (department_id);

-- Foreign key index for frontend_save_id
CREATE INDEX IF NOT EXISTS idx_employee_warnings_frontend_save_id ON public.employee_warnings USING btree (frontend_save_id);

-- Date index for fine_due_date
CREATE INDEX IF NOT EXISTS idx_employee_warnings_fine_due_date ON public.employee_warnings USING btree (fine_due_date);

-- Date index for fine_paid_date
CREATE INDEX IF NOT EXISTS idx_employee_warnings_fine_paid_date ON public.employee_warnings USING btree (fine_paid_date);

-- Date index for issued_at
CREATE INDEX IF NOT EXISTS idx_employee_warnings_issued_at ON public.employee_warnings USING btree (issued_at);

-- Date index for acknowledged_at
CREATE INDEX IF NOT EXISTS idx_employee_warnings_acknowledged_at ON public.employee_warnings USING btree (acknowledged_at);

-- Date index for resolved_at
CREATE INDEX IF NOT EXISTS idx_employee_warnings_resolved_at ON public.employee_warnings USING btree (resolved_at);

-- Date index for follow_up_date
CREATE INDEX IF NOT EXISTS idx_employee_warnings_follow_up_date ON public.employee_warnings USING btree (follow_up_date);

-- Date index for deleted_at
CREATE INDEX IF NOT EXISTS idx_employee_warnings_deleted_at ON public.employee_warnings USING btree (deleted_at);

-- Date index for fine_paid_at
CREATE INDEX IF NOT EXISTS idx_employee_warnings_fine_paid_at ON public.employee_warnings USING btree (fine_paid_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for employee_warnings

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.employee_warnings ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "employee_warnings_select_policy" ON public.employee_warnings
    FOR SELECT USING (true);

CREATE POLICY "employee_warnings_insert_policy" ON public.employee_warnings
    FOR INSERT WITH CHECK (true);

CREATE POLICY "employee_warnings_update_policy" ON public.employee_warnings
    FOR UPDATE USING (true);

CREATE POLICY "employee_warnings_delete_policy" ON public.employee_warnings
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for employee_warnings

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.employee_warnings (user_id, employee_id, username)
VALUES ('uuid-example', 'uuid-example', 'example');
*/

-- Select example
/*
SELECT * FROM public.employee_warnings 
WHERE user_id = $1;
*/

-- Update example
/*
UPDATE public.employee_warnings 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF EMPLOYEE_WARNINGS SCHEMA
-- ================================================================
