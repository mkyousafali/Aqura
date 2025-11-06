-- ================================================================
-- TABLE SCHEMA: push_subscriptions
-- Generated: 2025-11-06T11:09:39.016Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    device_id character varying NOT NULL,
    endpoint text NOT NULL,
    p256dh text NOT NULL,
    auth text NOT NULL,
    device_type character varying NOT NULL,
    browser_name character varying,
    user_agent text,
    is_active boolean DEFAULT true,
    last_seen timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    session_id text
);

-- Table comment
COMMENT ON TABLE public.push_subscriptions IS 'Table for push subscriptions management';

-- Column comments
COMMENT ON COLUMN public.push_subscriptions.id IS 'Primary key identifier';
COMMENT ON COLUMN public.push_subscriptions.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.push_subscriptions.device_id IS 'Foreign key reference to device table';
COMMENT ON COLUMN public.push_subscriptions.endpoint IS 'endpoint field';
COMMENT ON COLUMN public.push_subscriptions.p256dh IS 'p256dh field';
COMMENT ON COLUMN public.push_subscriptions.auth IS 'auth field';
COMMENT ON COLUMN public.push_subscriptions.device_type IS 'device type field';
COMMENT ON COLUMN public.push_subscriptions.browser_name IS 'Name field';
COMMENT ON COLUMN public.push_subscriptions.user_agent IS 'user agent field';
COMMENT ON COLUMN public.push_subscriptions.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.push_subscriptions.last_seen IS 'last seen field';
COMMENT ON COLUMN public.push_subscriptions.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.push_subscriptions.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.push_subscriptions.session_id IS 'Foreign key reference to session table';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS push_subscriptions_pkey ON public.push_subscriptions USING btree (id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON public.push_subscriptions USING btree (user_id);

-- Foreign key index for device_id
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_device_id ON public.push_subscriptions USING btree (device_id);

-- Foreign key index for session_id
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_session_id ON public.push_subscriptions USING btree (session_id);

-- Date index for last_seen
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_last_seen ON public.push_subscriptions USING btree (last_seen);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for push_subscriptions

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "push_subscriptions_select_policy" ON public.push_subscriptions
    FOR SELECT USING (true);

CREATE POLICY "push_subscriptions_insert_policy" ON public.push_subscriptions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "push_subscriptions_update_policy" ON public.push_subscriptions
    FOR UPDATE USING (true);

CREATE POLICY "push_subscriptions_delete_policy" ON public.push_subscriptions
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for push_subscriptions

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.push_subscriptions (user_id, device_id, endpoint)
VALUES ('uuid-example', 'example', 'example text');
*/

-- Select example
/*
SELECT * FROM public.push_subscriptions 
WHERE user_id = $1;
*/

-- Update example
/*
UPDATE public.push_subscriptions 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF PUSH_SUBSCRIPTIONS SCHEMA
-- ================================================================
