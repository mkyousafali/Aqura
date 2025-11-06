-- ================================================================
-- TABLE SCHEMA: recurring_schedule_check_log
-- Generated: 2025-11-06T11:09:39.021Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.recurring_schedule_check_log (
    id integer NOT NULL DEFAULT nextval('recurring_schedule_check_log_id_seq'::regclass),
    check_date date NOT NULL DEFAULT CURRENT_DATE,
    schedules_checked integer DEFAULT 0,
    notifications_sent integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.recurring_schedule_check_log IS 'Table for recurring schedule check log management';

-- Column comments
COMMENT ON COLUMN public.recurring_schedule_check_log.id IS 'Primary key identifier';
COMMENT ON COLUMN public.recurring_schedule_check_log.check_date IS 'Date field';
COMMENT ON COLUMN public.recurring_schedule_check_log.schedules_checked IS 'schedules checked field';
COMMENT ON COLUMN public.recurring_schedule_check_log.notifications_sent IS 'notifications sent field';
COMMENT ON COLUMN public.recurring_schedule_check_log.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS recurring_schedule_check_log_pkey ON public.recurring_schedule_check_log USING btree (id);

-- Date index for check_date
CREATE INDEX IF NOT EXISTS idx_recurring_schedule_check_log_check_date ON public.recurring_schedule_check_log USING btree (check_date);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for recurring_schedule_check_log

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.recurring_schedule_check_log ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "recurring_schedule_check_log_select_policy" ON public.recurring_schedule_check_log
    FOR SELECT USING (true);

CREATE POLICY "recurring_schedule_check_log_insert_policy" ON public.recurring_schedule_check_log
    FOR INSERT WITH CHECK (true);

CREATE POLICY "recurring_schedule_check_log_update_policy" ON public.recurring_schedule_check_log
    FOR UPDATE USING (true);

CREATE POLICY "recurring_schedule_check_log_delete_policy" ON public.recurring_schedule_check_log
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for recurring_schedule_check_log

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.recurring_schedule_check_log (check_date, schedules_checked, notifications_sent)
VALUES ('2025-11-06', 123, 123);
*/

-- Select example
/*
SELECT * FROM public.recurring_schedule_check_log 
WHERE id = $1;
*/

-- Update example
/*
UPDATE public.recurring_schedule_check_log 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF RECURRING_SCHEDULE_CHECK_LOG SCHEMA
-- ================================================================
