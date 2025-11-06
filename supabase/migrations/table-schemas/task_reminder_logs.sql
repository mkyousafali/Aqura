-- ================================================================
-- TABLE SCHEMA: task_reminder_logs
-- Generated: 2025-11-06T11:09:39.023Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.task_reminder_logs (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    task_assignment_id uuid,
    quick_task_assignment_id uuid,
    task_title text NOT NULL,
    assigned_to_user_id uuid,
    deadline timestamp with time zone NOT NULL,
    hours_overdue numeric,
    reminder_sent_at timestamp with time zone DEFAULT now(),
    notification_id uuid,
    status text DEFAULT 'sent'::text,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.task_reminder_logs IS 'Table for task reminder logs management';

-- Column comments
COMMENT ON COLUMN public.task_reminder_logs.id IS 'Primary key identifier';
COMMENT ON COLUMN public.task_reminder_logs.task_assignment_id IS 'Foreign key reference to task_assignment table';
COMMENT ON COLUMN public.task_reminder_logs.quick_task_assignment_id IS 'Foreign key reference to quick_task_assignment table';
COMMENT ON COLUMN public.task_reminder_logs.task_title IS 'task title field';
COMMENT ON COLUMN public.task_reminder_logs.assigned_to_user_id IS 'Foreign key reference to assigned_to_user table';
COMMENT ON COLUMN public.task_reminder_logs.deadline IS 'deadline field';
COMMENT ON COLUMN public.task_reminder_logs.hours_overdue IS 'hours overdue field';
COMMENT ON COLUMN public.task_reminder_logs.reminder_sent_at IS 'reminder sent at field';
COMMENT ON COLUMN public.task_reminder_logs.notification_id IS 'Foreign key reference to notification table';
COMMENT ON COLUMN public.task_reminder_logs.status IS 'Status indicator';
COMMENT ON COLUMN public.task_reminder_logs.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS task_reminder_logs_pkey ON public.task_reminder_logs USING btree (id);

-- Foreign key index for task_assignment_id
CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_task_assignment_id ON public.task_reminder_logs USING btree (task_assignment_id);

-- Foreign key index for quick_task_assignment_id
CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_quick_task_assignment_id ON public.task_reminder_logs USING btree (quick_task_assignment_id);

-- Foreign key index for assigned_to_user_id
CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_assigned_to_user_id ON public.task_reminder_logs USING btree (assigned_to_user_id);

-- Foreign key index for notification_id
CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_notification_id ON public.task_reminder_logs USING btree (notification_id);

-- Date index for deadline
CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_deadline ON public.task_reminder_logs USING btree (deadline);

-- Date index for reminder_sent_at
CREATE INDEX IF NOT EXISTS idx_task_reminder_logs_reminder_sent_at ON public.task_reminder_logs USING btree (reminder_sent_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for task_reminder_logs

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.task_reminder_logs ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "task_reminder_logs_select_policy" ON public.task_reminder_logs
    FOR SELECT USING (true);

CREATE POLICY "task_reminder_logs_insert_policy" ON public.task_reminder_logs
    FOR INSERT WITH CHECK (true);

CREATE POLICY "task_reminder_logs_update_policy" ON public.task_reminder_logs
    FOR UPDATE USING (true);

CREATE POLICY "task_reminder_logs_delete_policy" ON public.task_reminder_logs
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for task_reminder_logs

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.task_reminder_logs (task_assignment_id, quick_task_assignment_id, task_title)
VALUES ('uuid-example', 'uuid-example', 'example text');
*/

-- Select example
/*
SELECT * FROM public.task_reminder_logs 
WHERE task_assignment_id = $1;
*/

-- Update example
/*
UPDATE public.task_reminder_logs 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF TASK_REMINDER_LOGS SCHEMA
-- ================================================================
