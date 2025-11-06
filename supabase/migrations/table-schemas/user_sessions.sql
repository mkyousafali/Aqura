-- ================================================================
-- TABLE SCHEMA: user_sessions
-- Generated: 2025-11-06T11:09:39.025Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.user_sessions (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    user_id uuid NOT NULL,
    session_token character varying NOT NULL,
    login_method character varying NOT NULL,
    ip_address inet,
    user_agent text,
    is_active boolean DEFAULT true,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    ended_at timestamp with time zone
);

-- Table comment
COMMENT ON TABLE public.user_sessions IS 'Table for user sessions management';

-- Column comments
COMMENT ON COLUMN public.user_sessions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.user_sessions.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.user_sessions.session_token IS 'session token field';
COMMENT ON COLUMN public.user_sessions.login_method IS 'login method field';
COMMENT ON COLUMN public.user_sessions.ip_address IS 'Address information';
COMMENT ON COLUMN public.user_sessions.user_agent IS 'user agent field';
COMMENT ON COLUMN public.user_sessions.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.user_sessions.expires_at IS 'expires at field';
COMMENT ON COLUMN public.user_sessions.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.user_sessions.ended_at IS 'ended at field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS user_sessions_pkey ON public.user_sessions USING btree (id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON public.user_sessions USING btree (user_id);

-- Date index for expires_at
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON public.user_sessions USING btree (expires_at);

-- Date index for ended_at
CREATE INDEX IF NOT EXISTS idx_user_sessions_ended_at ON public.user_sessions USING btree (ended_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for user_sessions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.user_sessions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "user_sessions_select_policy" ON public.user_sessions
    FOR SELECT USING (true);

CREATE POLICY "user_sessions_insert_policy" ON public.user_sessions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "user_sessions_update_policy" ON public.user_sessions
    FOR UPDATE USING (true);

CREATE POLICY "user_sessions_delete_policy" ON public.user_sessions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for user_sessions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.user_sessions (user_id, session_token, login_method)
VALUES ('uuid-example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.user_sessions 
WHERE user_id = $1;
*/

-- Update example
/*
UPDATE public.user_sessions 
SET ended_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF USER_SESSIONS SCHEMA
-- ================================================================
