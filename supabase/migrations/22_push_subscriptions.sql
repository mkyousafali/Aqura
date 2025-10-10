-- Create push_subscriptions table for managing push notification subscriptions
-- This table stores device-specific push subscription data for web push notifications

-- Create the push_subscriptions table
CREATE TABLE IF NOT EXISTS public.push_subscriptions (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    device_id CHARACTER VARYING(100) NOT NULL,
    endpoint TEXT NOT NULL,
    p256dh TEXT NOT NULL,
    auth TEXT NOT NULL,
    device_type CHARACTER VARYING(20) NOT NULL,
    browser_name CHARACTER VARYING(50) NULL,
    user_agent TEXT NULL,
    is_active BOOLEAN NULL DEFAULT true,
    last_seen TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    session_id TEXT NULL,
    
    CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id),
    CONSTRAINT unique_session_subscription UNIQUE (user_id, session_id, endpoint),
    CONSTRAINT push_subscriptions_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT push_subscriptions_device_type_check 
        CHECK (device_type::text = ANY (ARRAY[
            'mobile'::character varying::text,
            'desktop'::character varying::text
        ]))
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id 
ON public.push_subscriptions USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_device_id 
ON public.push_subscriptions USING btree (device_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active 
ON public.push_subscriptions USING btree (is_active) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_last_seen 
ON public.push_subscriptions USING btree (last_seen) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_session 
ON public.push_subscriptions USING btree (user_id, device_id, session_id) 
TABLESPACE pg_default
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_cleanup 
ON public.push_subscriptions USING btree (user_id, last_seen, is_active) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active_user 
ON public.push_subscriptions USING btree (user_id, is_active) 
TABLESPACE pg_default
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_device_session 
ON public.push_subscriptions USING btree (device_id, session_id, is_active) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_endpoint 
ON public.push_subscriptions (endpoint);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_device_type 
ON public.push_subscriptions (device_type);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_browser 
ON public.push_subscriptions (browser_name) 
WHERE browser_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_created_at 
ON public.push_subscriptions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_stale 
ON public.push_subscriptions (last_seen) 
WHERE is_active = true AND last_seen < now() - INTERVAL '30 days';

-- Create unique index for endpoint to prevent duplicates
CREATE UNIQUE INDEX IF NOT EXISTS idx_push_subscriptions_unique_endpoint 
ON public.push_subscriptions (endpoint) 
WHERE is_active = true;

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION update_push_subscriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    
    -- Update last_seen when subscription is accessed
    IF TG_OP = 'UPDATE' AND NEW.is_active = true THEN
        NEW.last_seen = now();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the triggers (removing duplicate)
CREATE TRIGGER trigger_update_push_subscriptions_updated_at 
BEFORE UPDATE ON push_subscriptions 
FOR EACH ROW 
EXECUTE FUNCTION update_push_subscriptions_updated_at();

-- Add data validation constraints
ALTER TABLE public.push_subscriptions 
ADD CONSTRAINT chk_endpoint_not_empty 
CHECK (TRIM(endpoint) != '');

ALTER TABLE public.push_subscriptions 
ADD CONSTRAINT chk_p256dh_not_empty 
CHECK (TRIM(p256dh) != '');

ALTER TABLE public.push_subscriptions 
ADD CONSTRAINT chk_auth_not_empty 
CHECK (TRIM(auth) != '');

ALTER TABLE public.push_subscriptions 
ADD CONSTRAINT chk_device_id_not_empty 
CHECK (TRIM(device_id) != '');

ALTER TABLE public.push_subscriptions 
ADD CONSTRAINT chk_last_seen_reasonable 
CHECK (last_seen <= now() + INTERVAL '1 hour');

-- Add additional columns for better tracking
ALTER TABLE public.push_subscriptions 
ADD COLUMN IF NOT EXISTS subscription_count INTEGER DEFAULT 1;

ALTER TABLE public.push_subscriptions 
ADD COLUMN IF NOT EXISTS last_notification_sent TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.push_subscriptions 
ADD COLUMN IF NOT EXISTS failed_attempts INTEGER DEFAULT 0;

ALTER TABLE public.push_subscriptions 
ADD COLUMN IF NOT EXISTS last_error TEXT;

-- Add table and column comments
COMMENT ON TABLE public.push_subscriptions IS 'Web push notification subscriptions for users and devices';
COMMENT ON COLUMN public.push_subscriptions.id IS 'Unique identifier for the subscription';
COMMENT ON COLUMN public.push_subscriptions.user_id IS 'Reference to the user who owns this subscription';
COMMENT ON COLUMN public.push_subscriptions.device_id IS 'Unique identifier for the device';
COMMENT ON COLUMN public.push_subscriptions.endpoint IS 'Push service endpoint URL';
COMMENT ON COLUMN public.push_subscriptions.p256dh IS 'Public key for message encryption (P-256 ECDH)';
COMMENT ON COLUMN public.push_subscriptions.auth IS 'Authentication secret for message encryption';
COMMENT ON COLUMN public.push_subscriptions.device_type IS 'Type of device (mobile or desktop)';
COMMENT ON COLUMN public.push_subscriptions.browser_name IS 'Browser name if available';
COMMENT ON COLUMN public.push_subscriptions.user_agent IS 'Full user agent string';
COMMENT ON COLUMN public.push_subscriptions.is_active IS 'Whether this subscription is currently active';
COMMENT ON COLUMN public.push_subscriptions.last_seen IS 'Last time this subscription was seen active';
COMMENT ON COLUMN public.push_subscriptions.session_id IS 'Browser session identifier';
COMMENT ON COLUMN public.push_subscriptions.subscription_count IS 'Number of times this endpoint was subscribed';
COMMENT ON COLUMN public.push_subscriptions.last_notification_sent IS 'Timestamp of last notification sent to this subscription';
COMMENT ON COLUMN public.push_subscriptions.failed_attempts IS 'Number of consecutive failed delivery attempts';
COMMENT ON COLUMN public.push_subscriptions.last_error IS 'Last error message from push delivery attempt';

-- Create view for active subscriptions
CREATE OR REPLACE VIEW active_push_subscriptions AS
SELECT 
    ps.id,
    ps.user_id,
    u.username,
    u.full_name,
    ps.device_id,
    ps.endpoint,
    ps.device_type,
    ps.browser_name,
    ps.session_id,
    ps.last_seen,
    ps.created_at,
    ps.subscription_count,
    ps.failed_attempts,
    CASE 
        WHEN ps.last_seen > now() - INTERVAL '1 day' THEN 'active'
        WHEN ps.last_seen > now() - INTERVAL '7 days' THEN 'recent'
        WHEN ps.last_seen > now() - INTERVAL '30 days' THEN 'stale'
        ELSE 'inactive'
    END as activity_status
FROM push_subscriptions ps
JOIN users u ON ps.user_id = u.id
WHERE ps.is_active = true
ORDER BY ps.last_seen DESC;

-- Create function to register or update subscription
CREATE OR REPLACE FUNCTION upsert_push_subscription(
    p_user_id UUID,
    p_device_id VARCHAR,
    p_endpoint TEXT,
    p_p256dh TEXT,
    p_auth TEXT,
    p_device_type VARCHAR,
    p_browser_name VARCHAR DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_session_id TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    subscription_id UUID;
BEGIN
    -- Try to update existing subscription
    UPDATE push_subscriptions 
    SET endpoint = p_endpoint,
        p256dh = p_p256dh,
        auth = p_auth,
        device_type = p_device_type,
        browser_name = p_browser_name,
        user_agent = p_user_agent,
        session_id = p_session_id,
        is_active = true,
        last_seen = now(),
        subscription_count = subscription_count + 1,
        updated_at = now()
    WHERE user_id = p_user_id 
      AND device_id = p_device_id
    RETURNING id INTO subscription_id;
    
    -- If no existing subscription, create new one
    IF subscription_id IS NULL THEN
        INSERT INTO push_subscriptions (
            user_id, device_id, endpoint, p256dh, auth, device_type,
            browser_name, user_agent, session_id
        ) VALUES (
            p_user_id, p_device_id, p_endpoint, p_p256dh, p_auth, p_device_type,
            p_browser_name, p_user_agent, p_session_id
        ) RETURNING id INTO subscription_id;
    END IF;
    
    RETURN subscription_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to deactivate subscription
CREATE OR REPLACE FUNCTION deactivate_push_subscription(
    p_user_id UUID,
    p_device_id VARCHAR DEFAULT NULL,
    p_endpoint TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    affected_count INTEGER;
BEGIN
    UPDATE push_subscriptions 
    SET is_active = false,
        updated_at = now()
    WHERE user_id = p_user_id
      AND (p_device_id IS NULL OR device_id = p_device_id)
      AND (p_endpoint IS NULL OR endpoint = p_endpoint);
    
    GET DIAGNOSTICS affected_count = ROW_COUNT;
    RETURN affected_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get active subscriptions for user
CREATE OR REPLACE FUNCTION get_user_push_subscriptions(p_user_id UUID)
RETURNS TABLE(
    subscription_id UUID,
    device_id VARCHAR,
    endpoint TEXT,
    p256dh TEXT,
    auth TEXT,
    device_type VARCHAR,
    browser_name VARCHAR,
    last_seen TIMESTAMPTZ,
    failed_attempts INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ps.id,
        ps.device_id,
        ps.endpoint,
        ps.p256dh,
        ps.auth,
        ps.device_type,
        ps.browser_name,
        ps.last_seen,
        ps.failed_attempts
    FROM push_subscriptions ps
    WHERE ps.user_id = p_user_id 
      AND ps.is_active = true
    ORDER BY ps.last_seen DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to record notification delivery
CREATE OR REPLACE FUNCTION record_notification_delivery(
    subscription_id UUID,
    success BOOLEAN,
    error_message TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF success THEN
        UPDATE push_subscriptions 
        SET last_notification_sent = now(),
            failed_attempts = 0,
            last_error = NULL,
            updated_at = now()
        WHERE id = subscription_id;
    ELSE
        UPDATE push_subscriptions 
        SET failed_attempts = failed_attempts + 1,
            last_error = error_message,
            updated_at = now(),
            is_active = CASE 
                WHEN failed_attempts + 1 >= 5 THEN false 
                ELSE is_active 
            END
        WHERE id = subscription_id;
    END IF;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to cleanup stale subscriptions
CREATE OR REPLACE FUNCTION cleanup_stale_push_subscriptions(days_inactive INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deactivated_count INTEGER;
BEGIN
    UPDATE push_subscriptions 
    SET is_active = false,
        updated_at = now()
    WHERE is_active = true 
      AND last_seen < now() - (days_inactive * INTERVAL '1 day');
    
    GET DIAGNOSTICS deactivated_count = ROW_COUNT;
    RETURN deactivated_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get subscription statistics
CREATE OR REPLACE FUNCTION get_push_subscription_stats()
RETURNS TABLE(
    total_subscriptions BIGINT,
    active_subscriptions BIGINT,
    mobile_subscriptions BIGINT,
    desktop_subscriptions BIGINT,
    recent_subscriptions BIGINT,
    failed_subscriptions BIGINT,
    unique_users BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_subscriptions,
        COUNT(*) FILTER (WHERE is_active = true) as active_subscriptions,
        COUNT(*) FILTER (WHERE device_type = 'mobile' AND is_active = true) as mobile_subscriptions,
        COUNT(*) FILTER (WHERE device_type = 'desktop' AND is_active = true) as desktop_subscriptions,
        COUNT(*) FILTER (WHERE last_seen > now() - INTERVAL '7 days' AND is_active = true) as recent_subscriptions,
        COUNT(*) FILTER (WHERE failed_attempts >= 3 AND is_active = true) as failed_subscriptions,
        COUNT(DISTINCT user_id) FILTER (WHERE is_active = true) as unique_users
    FROM push_subscriptions;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'push_subscriptions table created with comprehensive subscription management features';