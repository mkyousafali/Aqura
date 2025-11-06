-- ================================================================
-- TABLE SCHEMA: employee_warning_history
-- Generated: 2025-11-06T11:09:39.007Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.employee_warning_history (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    warning_id uuid NOT NULL,
    action_type character varying NOT NULL,
    old_values jsonb,
    new_values jsonb,
    changed_by uuid,
    changed_by_username character varying,
    change_reason text,
    created_at timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address inet,
    user_agent text
);

-- Table comment
COMMENT ON TABLE public.employee_warning_history IS 'Table for employee warning history management';

-- Column comments
COMMENT ON COLUMN public.employee_warning_history.id IS 'Primary key identifier';
COMMENT ON COLUMN public.employee_warning_history.warning_id IS 'Foreign key reference to warning table';
COMMENT ON COLUMN public.employee_warning_history.action_type IS 'action type field';
COMMENT ON COLUMN public.employee_warning_history.old_values IS 'JSON data structure';
COMMENT ON COLUMN public.employee_warning_history.new_values IS 'JSON data structure';
COMMENT ON COLUMN public.employee_warning_history.changed_by IS 'changed by field';
COMMENT ON COLUMN public.employee_warning_history.changed_by_username IS 'Name field';
COMMENT ON COLUMN public.employee_warning_history.change_reason IS 'change reason field';
COMMENT ON COLUMN public.employee_warning_history.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.employee_warning_history.ip_address IS 'Address information';
COMMENT ON COLUMN public.employee_warning_history.user_agent IS 'user agent field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS employee_warning_history_pkey ON public.employee_warning_history USING btree (id);

-- Foreign key index for warning_id
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_warning_id ON public.employee_warning_history USING btree (warning_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for employee_warning_history

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.employee_warning_history ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "employee_warning_history_select_policy" ON public.employee_warning_history
    FOR SELECT USING (true);

CREATE POLICY "employee_warning_history_insert_policy" ON public.employee_warning_history
    FOR INSERT WITH CHECK (true);

CREATE POLICY "employee_warning_history_update_policy" ON public.employee_warning_history
    FOR UPDATE USING (true);

CREATE POLICY "employee_warning_history_delete_policy" ON public.employee_warning_history
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for employee_warning_history

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.employee_warning_history (warning_id, action_type, old_values)
VALUES ('uuid-example', 'example', '{}');
*/

-- Select example
/*
SELECT * FROM public.employee_warning_history 
WHERE warning_id = $1;
*/

-- Update example
/*
UPDATE public.employee_warning_history 
SET user_agent = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF EMPLOYEE_WARNING_HISTORY SCHEMA
-- ================================================================
