-- ================================================================
-- TABLE SCHEMA: user_audit_logs
-- Generated: 2025-11-06T11:09:39.024Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.user_audit_logs (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    user_id uuid,
    target_user_id uuid,
    action character varying NOT NULL,
    table_name character varying,
    record_id uuid,
    old_values jsonb,
    new_values jsonb,
    ip_address inet,
    user_agent text,
    performed_by uuid,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.user_audit_logs IS 'Table for user audit logs management';

-- Column comments
COMMENT ON COLUMN public.user_audit_logs.id IS 'Primary key identifier';
COMMENT ON COLUMN public.user_audit_logs.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.user_audit_logs.target_user_id IS 'Foreign key reference to target_user table';
COMMENT ON COLUMN public.user_audit_logs.action IS 'action field';
COMMENT ON COLUMN public.user_audit_logs.table_name IS 'Name field';
COMMENT ON COLUMN public.user_audit_logs.record_id IS 'Foreign key reference to record table';
COMMENT ON COLUMN public.user_audit_logs.old_values IS 'JSON data structure';
COMMENT ON COLUMN public.user_audit_logs.new_values IS 'JSON data structure';
COMMENT ON COLUMN public.user_audit_logs.ip_address IS 'Address information';
COMMENT ON COLUMN public.user_audit_logs.user_agent IS 'user agent field';
COMMENT ON COLUMN public.user_audit_logs.performed_by IS 'performed by field';
COMMENT ON COLUMN public.user_audit_logs.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS user_audit_logs_pkey ON public.user_audit_logs USING btree (id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_user_id ON public.user_audit_logs USING btree (user_id);

-- Foreign key index for target_user_id
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_target_user_id ON public.user_audit_logs USING btree (target_user_id);

-- Foreign key index for record_id
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_record_id ON public.user_audit_logs USING btree (record_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for user_audit_logs

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.user_audit_logs ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "user_audit_logs_select_policy" ON public.user_audit_logs
    FOR SELECT USING (true);

CREATE POLICY "user_audit_logs_insert_policy" ON public.user_audit_logs
    FOR INSERT WITH CHECK (true);

CREATE POLICY "user_audit_logs_update_policy" ON public.user_audit_logs
    FOR UPDATE USING (true);

CREATE POLICY "user_audit_logs_delete_policy" ON public.user_audit_logs
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for user_audit_logs

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.user_audit_logs (user_id, target_user_id, action)
VALUES ('uuid-example', 'uuid-example', 'example');
*/

-- Select example
/*
SELECT * FROM public.user_audit_logs 
WHERE user_id = $1;
*/

-- Update example
/*
UPDATE public.user_audit_logs 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF USER_AUDIT_LOGS SCHEMA
-- ================================================================
