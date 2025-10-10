-- Create user_device_sessions table for managing user sessions across different devices
-- This table tracks active sessions, device information, and session security

-- Create the user_device_sessions table
CREATE TABLE IF NOT EXISTS public.user_device_sessions (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    device_id CHARACTER VARYING(100) NOT NULL,
    session_token CHARACTER VARYING(255) NOT NULL,
    device_type CHARACTER VARYING(20) NOT NULL,
    browser_name CHARACTER VARYING(50) NULL,
    user_agent TEXT NULL,
    ip_address INET NULL,
    is_active BOOLEAN NULL DEFAULT true,
    login_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    last_activity TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    expires_at TIMESTAMP WITH TIME ZONE NULL DEFAULT (now() + '24:00:00'::interval),
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT user_device_sessions_pkey PRIMARY KEY (id),
    CONSTRAINT user_device_sessions_user_id_device_id_key UNIQUE (user_id, device_id),
    CONSTRAINT user_device_sessions_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT user_device_sessions_device_type_check 
        CHECK (device_type::text = ANY ((ARRAY['mobile'::character varying, 'desktop'::character varying])::text[]))
) TABLESPACE pg_default;

-- Create indexes for efficient queries (original indexes)
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user_id 
ON public.user_device_sessions USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_device_id 
ON public.user_device_sessions USING btree (device_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_active 
ON public.user_device_sessions USING btree (is_active) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_expires_at 
ON public.user_device_sessions USING btree (expires_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_last_activity 
ON public.user_device_sessions USING btree (last_activity) 
TABLESPACE pg_default;

-- Create the updated_at trigger function first
CREATE OR REPLACE FUNCTION update_user_device_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create original trigger
CREATE TRIGGER trigger_user_device_sessions_updated_at 
BEFORE UPDATE ON user_device_sessions 
FOR EACH ROW 
EXECUTE FUNCTION update_user_device_sessions_updated_at();

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_session_token 
ON public.user_device_sessions (session_token);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_browser_name 
ON public.user_device_sessions (browser_name);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_ip_address 
ON public.user_device_sessions (ip_address);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_login_at 
ON public.user_device_sessions (login_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_created_at 
ON public.user_device_sessions (created_at DESC);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user_active 
ON public.user_device_sessions (user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user_device_type 
ON public.user_device_sessions (user_id, device_type);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_active_last_activity 
ON public.user_device_sessions (is_active, last_activity DESC);

-- Create partial indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_active_sessions 
ON public.user_device_sessions (last_activity DESC) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_expired_sessions 
ON public.user_device_sessions (expires_at) 
WHERE is_active = true AND expires_at < now();

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_mobile_sessions 
ON public.user_device_sessions (user_id, last_activity DESC) 
WHERE device_type = 'mobile' AND is_active = true;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_desktop_sessions 
ON public.user_device_sessions (user_id, last_activity DESC) 
WHERE device_type = 'desktop' AND is_active = true;

-- Add additional validation constraints
ALTER TABLE public.user_device_sessions 
ADD CONSTRAINT chk_session_token_not_empty 
CHECK (TRIM(session_token) != '');

ALTER TABLE public.user_device_sessions 
ADD CONSTRAINT chk_device_id_not_empty 
CHECK (TRIM(device_id) != '');

ALTER TABLE public.user_device_sessions 
ADD CONSTRAINT chk_expires_at_after_login 
CHECK (expires_at > login_at);

ALTER TABLE public.user_device_sessions 
ADD CONSTRAINT chk_last_activity_after_login 
CHECK (last_activity >= login_at);

-- Extend device_type constraint to include more types
ALTER TABLE public.user_device_sessions 
DROP CONSTRAINT IF EXISTS user_device_sessions_device_type_check;

ALTER TABLE public.user_device_sessions 
ADD CONSTRAINT chk_device_type_valid 
CHECK (device_type IN ('mobile', 'desktop', 'tablet', 'tv', 'watch', 'other'));

-- Add additional columns for enhanced functionality
ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS device_name VARCHAR(100);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS os_name VARCHAR(50);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS os_version VARCHAR(50);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS browser_version VARCHAR(50);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS screen_resolution VARCHAR(20);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS timezone VARCHAR(50);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS language VARCHAR(10);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS country_code VARCHAR(2);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS city VARCHAR(100);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS logout_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS logout_reason VARCHAR(50);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS is_trusted BOOLEAN DEFAULT false;

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS login_method VARCHAR(50) DEFAULT 'password';

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS two_factor_verified BOOLEAN DEFAULT false;

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS device_fingerprint TEXT;

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS push_token VARCHAR(255);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS session_metadata JSONB DEFAULT '{}';

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS security_flags JSONB DEFAULT '{}';

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS refresh_token VARCHAR(255);

ALTER TABLE public.user_device_sessions 
ADD COLUMN IF NOT EXISTS refresh_expires_at TIMESTAMP WITH TIME ZONE;

-- Add validation for new columns
ALTER TABLE public.user_device_sessions 
ADD CONSTRAINT chk_logout_reason_valid 
CHECK (logout_reason IS NULL OR logout_reason IN (
    'user_logout', 'session_expired', 'forced_logout', 'device_removed', 'security_breach', 'admin_action'
));

ALTER TABLE public.user_device_sessions 
ADD CONSTRAINT chk_login_method_valid 
CHECK (login_method IN (
    'password', 'google', 'facebook', 'apple', 'microsoft', 'sso', 'biometric', 'magic_link'
));

ALTER TABLE public.user_device_sessions 
ADD CONSTRAINT chk_logout_after_login 
CHECK (logout_at IS NULL OR logout_at >= login_at);

ALTER TABLE public.user_device_sessions 
ADD CONSTRAINT chk_refresh_expires_after_expires 
CHECK (refresh_expires_at IS NULL OR refresh_expires_at >= expires_at);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_device_name 
ON public.user_device_sessions (device_name);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_os_name 
ON public.user_device_sessions (os_name);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_country_code 
ON public.user_device_sessions (country_code);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_logout_at 
ON public.user_device_sessions (logout_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_logout_reason 
ON public.user_device_sessions (logout_reason);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_is_trusted 
ON public.user_device_sessions (is_trusted) 
WHERE is_trusted = true;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_login_method 
ON public.user_device_sessions (login_method);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_two_factor 
ON public.user_device_sessions (two_factor_verified) 
WHERE two_factor_verified = true;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_device_fingerprint 
ON public.user_device_sessions (device_fingerprint);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_push_token 
ON public.user_device_sessions (push_token);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_refresh_token 
ON public.user_device_sessions (refresh_token);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_refresh_expires 
ON public.user_device_sessions (refresh_expires_at);

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_metadata 
ON public.user_device_sessions USING gin (session_metadata);

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_security_flags 
ON public.user_device_sessions USING gin (security_flags);

-- Create unique constraint for session tokens
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_device_sessions_session_token_unique 
ON public.user_device_sessions (session_token) 
WHERE is_active = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_user_device_sessions_refresh_token_unique 
ON public.user_device_sessions (refresh_token) 
WHERE refresh_token IS NOT NULL AND is_active = true;

-- Add table and column comments
COMMENT ON TABLE public.user_device_sessions IS 'User device sessions with comprehensive device tracking and security features';
COMMENT ON COLUMN public.user_device_sessions.id IS 'Unique identifier for the session';
COMMENT ON COLUMN public.user_device_sessions.user_id IS 'Reference to the user';
COMMENT ON COLUMN public.user_device_sessions.device_id IS 'Unique device identifier';
COMMENT ON COLUMN public.user_device_sessions.session_token IS 'Session authentication token';
COMMENT ON COLUMN public.user_device_sessions.device_type IS 'Type of device (mobile, desktop, etc.)';
COMMENT ON COLUMN public.user_device_sessions.browser_name IS 'Name of the browser';
COMMENT ON COLUMN public.user_device_sessions.user_agent IS 'Full user agent string';
COMMENT ON COLUMN public.user_device_sessions.ip_address IS 'IP address of the session';
COMMENT ON COLUMN public.user_device_sessions.is_active IS 'Whether the session is currently active';
COMMENT ON COLUMN public.user_device_sessions.login_at IS 'When the session was created';
COMMENT ON COLUMN public.user_device_sessions.last_activity IS 'Last activity timestamp';
COMMENT ON COLUMN public.user_device_sessions.expires_at IS 'When the session expires';
COMMENT ON COLUMN public.user_device_sessions.device_name IS 'Human-readable device name';
COMMENT ON COLUMN public.user_device_sessions.os_name IS 'Operating system name';
COMMENT ON COLUMN public.user_device_sessions.os_version IS 'Operating system version';
COMMENT ON COLUMN public.user_device_sessions.browser_version IS 'Browser version';
COMMENT ON COLUMN public.user_device_sessions.screen_resolution IS 'Screen resolution of the device';
COMMENT ON COLUMN public.user_device_sessions.timezone IS 'Device timezone';
COMMENT ON COLUMN public.user_device_sessions.language IS 'Device/browser language';
COMMENT ON COLUMN public.user_device_sessions.country_code IS 'Country code based on IP';
COMMENT ON COLUMN public.user_device_sessions.city IS 'City based on IP geolocation';
COMMENT ON COLUMN public.user_device_sessions.logout_at IS 'When the session was logged out';
COMMENT ON COLUMN public.user_device_sessions.logout_reason IS 'Reason for logout';
COMMENT ON COLUMN public.user_device_sessions.is_trusted IS 'Whether the device is trusted';
COMMENT ON COLUMN public.user_device_sessions.login_method IS 'Method used for login';
COMMENT ON COLUMN public.user_device_sessions.two_factor_verified IS 'Whether 2FA was completed';
COMMENT ON COLUMN public.user_device_sessions.device_fingerprint IS 'Device fingerprint for identification';
COMMENT ON COLUMN public.user_device_sessions.push_token IS 'Push notification token';
COMMENT ON COLUMN public.user_device_sessions.session_metadata IS 'Additional session metadata';
COMMENT ON COLUMN public.user_device_sessions.security_flags IS 'Security-related flags and settings';
COMMENT ON COLUMN public.user_device_sessions.refresh_token IS 'Token for refreshing the session';
COMMENT ON COLUMN public.user_device_sessions.refresh_expires_at IS 'When the refresh token expires';
COMMENT ON COLUMN public.user_device_sessions.created_at IS 'When the record was created';
COMMENT ON COLUMN public.user_device_sessions.updated_at IS 'When the record was last updated';

-- Create view for active sessions with user details
CREATE OR REPLACE VIEW user_device_sessions_active AS
SELECT 
    uds.id,
    uds.user_id,
    u.username,
    u.full_name as user_name,
    uds.device_id,
    uds.device_name,
    uds.device_type,
    uds.browser_name,
    uds.browser_version,
    uds.os_name,
    uds.os_version,
    uds.ip_address,
    uds.country_code,
    uds.city,
    uds.login_method,
    uds.is_trusted,
    uds.two_factor_verified,
    uds.login_at,
    uds.last_activity,
    uds.expires_at,
    uds.session_metadata,
    uds.security_flags,
    EXTRACT(EPOCH FROM (now() - uds.last_activity)) / 60 as minutes_since_last_activity,
    EXTRACT(EPOCH FROM (uds.expires_at - now())) / 60 as minutes_until_expiry,
    CASE 
        WHEN uds.expires_at < now() THEN true
        ELSE false
    END as is_expired
FROM user_device_sessions uds
LEFT JOIN users u ON uds.user_id = u.id
WHERE uds.is_active = true
ORDER BY uds.last_activity DESC;

-- Create function to create a new session
CREATE OR REPLACE FUNCTION create_user_session(
    user_id_param UUID,
    device_id_param VARCHAR,
    session_token_param VARCHAR,
    device_type_param VARCHAR,
    browser_name_param VARCHAR DEFAULT NULL,
    user_agent_param TEXT DEFAULT NULL,
    ip_address_param INET DEFAULT NULL,
    device_name_param VARCHAR DEFAULT NULL,
    os_name_param VARCHAR DEFAULT NULL,
    os_version_param VARCHAR DEFAULT NULL,
    browser_version_param VARCHAR DEFAULT NULL,
    timezone_param VARCHAR DEFAULT NULL,
    language_param VARCHAR DEFAULT NULL,
    country_code_param VARCHAR DEFAULT NULL,
    city_param VARCHAR DEFAULT NULL,
    login_method_param VARCHAR DEFAULT 'password',
    is_trusted_param BOOLEAN DEFAULT false,
    device_fingerprint_param TEXT DEFAULT NULL,
    push_token_param VARCHAR DEFAULT NULL,
    session_duration_hours INTEGER DEFAULT 24,
    metadata_param JSONB DEFAULT '{}',
    security_flags_param JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    session_id UUID;
    expires_at_calculated TIMESTAMPTZ;
    refresh_expires_at_calculated TIMESTAMPTZ;
    refresh_token_generated VARCHAR;
BEGIN
    -- Calculate expiration times
    expires_at_calculated := now() + (session_duration_hours || ' hours')::INTERVAL;
    refresh_expires_at_calculated := now() + ((session_duration_hours * 2) || ' hours')::INTERVAL;
    
    -- Generate refresh token
    refresh_token_generated := encode(gen_random_bytes(32), 'base64');
    
    -- Deactivate any existing sessions for this user-device combination
    UPDATE user_device_sessions 
    SET is_active = false,
        logout_at = now(),
        logout_reason = 'new_session',
        updated_at = now()
    WHERE user_id = user_id_param 
      AND device_id = device_id_param 
      AND is_active = true;
    
    INSERT INTO user_device_sessions (
        user_id,
        device_id,
        session_token,
        device_type,
        browser_name,
        user_agent,
        ip_address,
        device_name,
        os_name,
        os_version,
        browser_version,
        timezone,
        language,
        country_code,
        city,
        login_method,
        is_trusted,
        device_fingerprint,
        push_token,
        expires_at,
        refresh_token,
        refresh_expires_at,
        session_metadata,
        security_flags
    ) VALUES (
        user_id_param,
        device_id_param,
        session_token_param,
        device_type_param,
        browser_name_param,
        user_agent_param,
        ip_address_param,
        device_name_param,
        os_name_param,
        os_version_param,
        browser_version_param,
        timezone_param,
        language_param,
        country_code_param,
        city_param,
        login_method_param,
        is_trusted_param,
        device_fingerprint_param,
        push_token_param,
        expires_at_calculated,
        refresh_token_generated,
        refresh_expires_at_calculated,
        metadata_param,
        security_flags_param
    ) RETURNING id INTO session_id;
    
    RETURN session_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update session activity
CREATE OR REPLACE FUNCTION update_session_activity(
    session_token_param VARCHAR,
    ip_address_param INET DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE user_device_sessions 
    SET last_activity = now(),
        ip_address = COALESCE(ip_address_param, ip_address),
        updated_at = now()
    WHERE session_token = session_token_param 
      AND is_active = true 
      AND expires_at > now();
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to logout a session
CREATE OR REPLACE FUNCTION logout_session(
    session_token_param VARCHAR,
    logout_reason_param VARCHAR DEFAULT 'user_logout'
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE user_device_sessions 
    SET is_active = false,
        logout_at = now(),
        logout_reason = logout_reason_param,
        updated_at = now()
    WHERE session_token = session_token_param 
      AND is_active = true;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to logout all user sessions
CREATE OR REPLACE FUNCTION logout_all_user_sessions(
    user_id_param UUID,
    logout_reason_param VARCHAR DEFAULT 'logout_all',
    exclude_session_token VARCHAR DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    logout_count INTEGER;
BEGIN
    UPDATE user_device_sessions 
    SET is_active = false,
        logout_at = now(),
        logout_reason = logout_reason_param,
        updated_at = now()
    WHERE user_id = user_id_param 
      AND is_active = true
      AND (exclude_session_token IS NULL OR session_token != exclude_session_token);
    
    GET DIAGNOSTICS logout_count = ROW_COUNT;
    RETURN logout_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to cleanup expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    cleanup_count INTEGER;
BEGIN
    UPDATE user_device_sessions 
    SET is_active = false,
        logout_at = now(),
        logout_reason = 'session_expired',
        updated_at = now()
    WHERE is_active = true 
      AND expires_at < now();
    
    GET DIAGNOSTICS cleanup_count = ROW_COUNT;
    RETURN cleanup_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to refresh a session
CREATE OR REPLACE FUNCTION refresh_session(
    refresh_token_param VARCHAR,
    new_session_token VARCHAR,
    session_duration_hours INTEGER DEFAULT 24
)
RETURNS BOOLEAN AS $$
DECLARE
    new_expires_at TIMESTAMPTZ;
    new_refresh_token VARCHAR;
    new_refresh_expires_at TIMESTAMPTZ;
BEGIN
    new_expires_at := now() + (session_duration_hours || ' hours')::INTERVAL;
    new_refresh_token := encode(gen_random_bytes(32), 'base64');
    new_refresh_expires_at := now() + ((session_duration_hours * 2) || ' hours')::INTERVAL;
    
    UPDATE user_device_sessions 
    SET session_token = new_session_token,
        expires_at = new_expires_at,
        refresh_token = new_refresh_token,
        refresh_expires_at = new_refresh_expires_at,
        last_activity = now(),
        updated_at = now()
    WHERE refresh_token = refresh_token_param 
      AND is_active = true 
      AND refresh_expires_at > now();
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get user session statistics
CREATE OR REPLACE FUNCTION get_user_session_statistics(
    user_id_param UUID,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_sessions BIGINT,
    active_sessions BIGINT,
    mobile_sessions BIGINT,
    desktop_sessions BIGINT,
    trusted_devices BIGINT,
    unique_ips BIGINT,
    unique_countries BIGINT,
    avg_session_duration INTERVAL,
    last_login_at TIMESTAMPTZ,
    most_used_device_type VARCHAR,
    most_used_browser VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_sessions,
        COUNT(*) FILTER (WHERE is_active = true) as active_sessions,
        COUNT(*) FILTER (WHERE device_type = 'mobile') as mobile_sessions,
        COUNT(*) FILTER (WHERE device_type = 'desktop') as desktop_sessions,
        COUNT(*) FILTER (WHERE is_trusted = true) as trusted_devices,
        COUNT(DISTINCT ip_address) as unique_ips,
        COUNT(DISTINCT country_code) as unique_countries,
        AVG(COALESCE(logout_at, expires_at) - login_at) as avg_session_duration,
        MAX(login_at) as last_login_at,
        (SELECT device_type FROM user_device_sessions WHERE user_id = user_id_param 
         AND (date_from IS NULL OR login_at >= date_from)
         AND (date_to IS NULL OR login_at <= date_to)
         GROUP BY device_type ORDER BY COUNT(*) DESC LIMIT 1) as most_used_device_type,
        (SELECT browser_name FROM user_device_sessions WHERE user_id = user_id_param 
         AND browser_name IS NOT NULL
         AND (date_from IS NULL OR login_at >= date_from)
         AND (date_to IS NULL OR login_at <= date_to)
         GROUP BY browser_name ORDER BY COUNT(*) DESC LIMIT 1) as most_used_browser
    FROM user_device_sessions
    WHERE user_id = user_id_param
      AND (date_from IS NULL OR login_at >= date_from)
      AND (date_to IS NULL OR login_at <= date_to);
END;
$$ LANGUAGE plpgsql;

-- Create function to detect suspicious sessions
CREATE OR REPLACE FUNCTION detect_suspicious_sessions(
    user_id_param UUID DEFAULT NULL,
    hours_lookback INTEGER DEFAULT 24
)
RETURNS TABLE(
    session_id UUID,
    user_id UUID,
    username VARCHAR,
    device_id VARCHAR,
    ip_address INET,
    country_code VARCHAR,
    login_at TIMESTAMPTZ,
    suspicious_reasons TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    WITH session_analysis AS (
        SELECT 
            uds.id,
            uds.user_id,
            u.username,
            uds.device_id,
            uds.ip_address,
            uds.country_code,
            uds.login_at,
            ARRAY[]::TEXT[] as reasons
        FROM user_device_sessions uds
        LEFT JOIN users u ON uds.user_id = u.id
        WHERE uds.login_at >= now() - (hours_lookback || ' hours')::INTERVAL
          AND (user_id_param IS NULL OR uds.user_id = user_id_param)
    ),
    suspicious_analysis AS (
        SELECT 
            sa.*,
            CASE 
                WHEN NOT EXISTS (
                    SELECT 1 FROM user_device_sessions uds2 
                    WHERE uds2.user_id = sa.user_id 
                      AND uds2.ip_address = sa.ip_address 
                      AND uds2.login_at < sa.login_at - INTERVAL '7 days'
                ) THEN sa.reasons || 'new_ip_address'
                ELSE sa.reasons
            END as updated_reasons_1,
            CASE 
                WHEN EXISTS (
                    SELECT 1 FROM user_device_sessions uds3 
                    WHERE uds3.user_id = sa.user_id 
                      AND uds3.country_code != sa.country_code 
                      AND uds3.login_at >= sa.login_at - INTERVAL '1 hour'
                      AND uds3.login_at <= sa.login_at + INTERVAL '1 hour'
                ) THEN sa.reasons || 'multiple_countries'
                ELSE sa.reasons
            END as updated_reasons_2
        FROM session_analysis sa
    )
    SELECT 
        sas.id,
        sas.user_id,
        sas.username,
        sas.device_id,
        sas.ip_address,
        sas.country_code,
        sas.login_at,
        COALESCE(sas.updated_reasons_1, '{}') || COALESCE(sas.updated_reasons_2, '{}') as suspicious_reasons
    FROM suspicious_analysis sas
    WHERE array_length(COALESCE(sas.updated_reasons_1, '{}') || COALESCE(sas.updated_reasons_2, '{}'), 1) > 0
    ORDER BY sas.login_at DESC;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'user_device_sessions table created with comprehensive session management and security features';