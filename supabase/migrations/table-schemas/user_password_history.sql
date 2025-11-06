-- ================================================================
-- TABLE SCHEMA: user_password_history
-- Generated: 2025-11-06T11:09:39.024Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.user_password_history (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    user_id uuid NOT NULL,
    password_hash character varying NOT NULL,
    salt character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.user_password_history IS 'Table for user password history management';

-- Column comments
COMMENT ON COLUMN public.user_password_history.id IS 'Primary key identifier';
COMMENT ON COLUMN public.user_password_history.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.user_password_history.password_hash IS 'password hash field';
COMMENT ON COLUMN public.user_password_history.salt IS 'salt field';
COMMENT ON COLUMN public.user_password_history.created_at IS 'Timestamp when record was created';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS user_password_history_pkey ON public.user_password_history USING btree (id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_user_password_history_user_id ON public.user_password_history USING btree (user_id);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for user_password_history

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.user_password_history ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "user_password_history_select_policy" ON public.user_password_history
    FOR SELECT USING (true);

CREATE POLICY "user_password_history_insert_policy" ON public.user_password_history
    FOR INSERT WITH CHECK (true);

CREATE POLICY "user_password_history_update_policy" ON public.user_password_history
    FOR UPDATE USING (true);

CREATE POLICY "user_password_history_delete_policy" ON public.user_password_history
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for user_password_history

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.user_password_history (user_id, password_hash, salt)
VALUES ('uuid-example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.user_password_history 
WHERE user_id = $1;
*/

-- Update example
/*
UPDATE public.user_password_history 
SET created_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF USER_PASSWORD_HISTORY SCHEMA
-- ================================================================
