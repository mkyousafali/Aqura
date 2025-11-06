-- ================================================================
-- TABLE SCHEMA: user_device_sessions
-- Generated: 2025-11-06T11:09:39.024Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.user_device_sessions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    device_id character varying NOT NULL,
    session_token character varying NOT NULL,
    device_type character varying NOT NULL,
    browser_name character varying,
    user_agent text,
    ip_address inet,
    is_active boolean DEFAULT true,
    login_at timestamp with time zone DEFAULT now(),
    last_activity timestamp with time zone DEFAULT now(),
    expires_at timestamp with time zone DEFAULT (now() + '24:00:00'::interval),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Table comment
COMMENT ON TABLE public.user_device_sessions IS 'Table for user device sessions management';

-- Column comments
COMMENT ON COLUMN public.user_device_sessions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.user_device_sessions.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.user_device_sessions.device_id IS 'Foreign key reference to device table';
COMMENT ON COLUMN public.user_device_sessions.session_token IS 'session token field';
COMMENT ON COLUMN public.user_device_sessions.device_type IS 'device type field';
COMMENT ON COLUMN public.user_device_sessions.browser_name IS 'Name field';
COMMENT ON COLUMN public.user_device_sessions.user_agent IS 'user agent field';
COMMENT ON COLUMN public.user_device_sessions.ip_address IS 'Address information';
COMMENT ON COLUMN public.user_device_sessions.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.user_device_sessions.login_at IS 'login at field';
COMMENT ON COLUMN public.user_device_sessions.last_activity IS 'last activity field';
COMMENT ON COLUMN public.user_device_sessions.expires_at IS 'expires at field';
COMMENT ON COLUMN public.user_device_sessions.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.user_device_sessions.updated_at IS 'Timestamp when record was last updated';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS user_device_sessions_pkey ON public.user_device_sessions USING btree (id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user_id ON public.user_device_sessions USING btree (user_id);

-- Foreign key index for device_id
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_device_id ON public.user_device_sessions USING btree (device_id);

-- Date index for login_at
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_login_at ON public.user_device_sessions USING btree (login_at);

-- Date index for last_activity
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_last_activity ON public.user_device_sessions USING btree (last_activity);

-- Date index for expires_at
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_expires_at ON public.user_device_sessions USING btree (expires_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for user_device_sessions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.user_device_sessions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "user_device_sessions_select_policy" ON public.user_device_sessions
    FOR SELECT USING (true);

CREATE POLICY "user_device_sessions_insert_policy" ON public.user_device_sessions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "user_device_sessions_update_policy" ON public.user_device_sessions
    FOR UPDATE USING (true);

CREATE POLICY "user_device_sessions_delete_policy" ON public.user_device_sessions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for user_device_sessions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.user_device_sessions (user_id, device_id, session_token)
VALUES ('uuid-example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.user_device_sessions 
WHERE user_id = $1;
*/

-- Update example
/*
UPDATE public.user_device_sessions 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF USER_DEVICE_SESSIONS SCHEMA
-- ================================================================
