-- Create user_sessions table for session management and authentication tracking
-- This table manages user sessions with comprehensive security and monitoring features

-- Create the user_sessions table
CREATE TABLE IF NOT EXISTS public.user_sessions (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL,
    session_token CHARACTER VARYING(255) NOT NULL,
    login_method CHARACTER VARYING(20) NOT NULL,
    ip_address INET NULL,
    user_agent TEXT NULL,
    is_active BOOLEAN NULL DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    ended_at TIMESTAMP WITH TIME ZONE NULL,
    
    CONSTRAINT user_sessions_pkey PRIMARY KEY (id),
    CONSTRAINT user_sessions_session_token_key UNIQUE (session_token),
    CONSTRAINT user_sessions_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT user_sessions_login_method_check 
        CHECK ((login_method)::text = ANY ((ARRAY[
            'quick_access'::character varying,
            'username_password'::character varying
        ])::text[]))
) TABLESPACE pg_default;

-- Create original indexes
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id 
ON public.user_sessions USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_sessions_token 
ON public.user_sessions USING btree (session_token) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_sessions_active 
ON public.user_sessions USING btree (is_active) 
TABLESPACE pg_default;

-- Add additional columns for enhanced functionality
ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS session_type VARCHAR(30) DEFAULT 'web';

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS device_info JSONB DEFAULT '{}';

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS location_info JSONB DEFAULT '{}';

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT now();

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS refresh_token VARCHAR(255);

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS refresh_expires_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS session_metadata JSONB DEFAULT '{}';

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS security_flags JSONB DEFAULT '{}';

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS is_trusted_device BOOLEAN DEFAULT false;

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS device_fingerprint VARCHAR(255);

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS login_attempts INTEGER DEFAULT 1;

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS two_factor_verified BOOLEAN DEFAULT false;

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS session_duration_seconds INTEGER;

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS logout_reason VARCHAR(50);

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS is_concurrent_limit_exceeded BOOLEAN DEFAULT false;

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS parent_session_id UUID;

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS is_impersonation BOOLEAN DEFAULT false;

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS impersonated_by UUID;

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS browser_name VARCHAR(50);

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS browser_version VARCHAR(20);

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS os_name VARCHAR(50);

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS os_version VARCHAR(20);

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS is_mobile BOOLEAN DEFAULT false;

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS timezone VARCHAR(50);

ALTER TABLE public.user_sessions 
ADD COLUMN IF NOT EXISTS language_preference VARCHAR(10);

-- Add foreign key constraints for new columns
ALTER TABLE public.user_sessions 
ADD CONSTRAINT user_sessions_parent_session_fkey 
FOREIGN KEY (parent_session_id) REFERENCES user_sessions (id) ON DELETE SET NULL;

ALTER TABLE public.user_sessions 
ADD CONSTRAINT user_sessions_impersonated_by_fkey 
FOREIGN KEY (impersonated_by) REFERENCES users (id) ON DELETE SET NULL;

-- Update login method constraint to include more methods
ALTER TABLE public.user_sessions 
DROP CONSTRAINT IF EXISTS user_sessions_login_method_check;

ALTER TABLE public.user_sessions 
ADD CONSTRAINT user_sessions_login_method_check 
CHECK ((login_method)::text = ANY ((ARRAY[
    'quick_access'::character varying,
    'username_password'::character varying,
    'sso'::character varying,
    'oauth'::character varying,
    'magic_link'::character varying,
    'two_factor'::character varying,
    'biometric'::character varying,
    'api_key'::character varying,
    'impersonation'::character varying
])::text[]));

-- Add validation constraints
ALTER TABLE public.user_sessions 
ADD CONSTRAINT chk_session_token_not_empty 
CHECK (TRIM(session_token) != '');

ALTER TABLE public.user_sessions 
ADD CONSTRAINT chk_expires_at_future 
CHECK (expires_at > created_at);

ALTER TABLE public.user_sessions 
ADD CONSTRAINT chk_ended_at_after_created 
CHECK (ended_at IS NULL OR ended_at >= created_at);

ALTER TABLE public.user_sessions 
ADD CONSTRAINT chk_last_activity_valid 
CHECK (last_activity_at >= created_at);

ALTER TABLE public.user_sessions 
ADD CONSTRAINT chk_refresh_expires_valid 
CHECK (refresh_expires_at IS NULL OR refresh_expires_at > expires_at);

ALTER TABLE public.user_sessions 
ADD CONSTRAINT chk_session_type_valid 
CHECK (session_type IN ('web', 'mobile', 'api', 'desktop', 'embedded', 'kiosk'));

ALTER TABLE public.user_sessions 
ADD CONSTRAINT chk_login_attempts_positive 
CHECK (login_attempts > 0);

ALTER TABLE public.user_sessions 
ADD CONSTRAINT chk_session_duration_positive 
CHECK (session_duration_seconds IS NULL OR session_duration_seconds > 0);

ALTER TABLE public.user_sessions 
ADD CONSTRAINT chk_logout_reason_valid 
CHECK (logout_reason IS NULL OR logout_reason IN (
    'user_logout', 'timeout', 'admin_terminated', 'security_breach', 
    'concurrent_limit', 'password_changed', 'account_disabled', 'expired',
    'device_changed', 'suspicious_activity', 'forced_logout', 'system_maintenance'
));

-- Create additional indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at 
ON public.user_sessions (expires_at);

CREATE INDEX IF NOT EXISTS idx_user_sessions_created_at 
ON public.user_sessions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_sessions_last_activity 
ON public.user_sessions (last_activity_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_sessions_ended_at 
ON public.user_sessions (ended_at) 
WHERE ended_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_sessions_ip_address 
ON public.user_sessions (ip_address);

CREATE INDEX IF NOT EXISTS idx_user_sessions_login_method 
ON public.user_sessions (login_method);

CREATE INDEX IF NOT EXISTS idx_user_sessions_session_type 
ON public.user_sessions (session_type);

CREATE INDEX IF NOT EXISTS idx_user_sessions_device_fingerprint 
ON public.user_sessions (device_fingerprint);

CREATE INDEX IF NOT EXISTS idx_user_sessions_trusted_device 
ON public.user_sessions (is_trusted_device) 
WHERE is_trusted_device = true;

CREATE INDEX IF NOT EXISTS idx_user_sessions_two_factor 
ON public.user_sessions (two_factor_verified);

CREATE INDEX IF NOT EXISTS idx_user_sessions_impersonation 
ON public.user_sessions (is_impersonation, impersonated_by) 
WHERE is_impersonation = true;

CREATE INDEX IF NOT EXISTS idx_user_sessions_parent 
ON public.user_sessions (parent_session_id);

CREATE INDEX IF NOT EXISTS idx_user_sessions_mobile 
ON public.user_sessions (is_mobile) 
WHERE is_mobile = true;

CREATE INDEX IF NOT EXISTS idx_user_sessions_browser 
ON public.user_sessions (browser_name, browser_version);

CREATE INDEX IF NOT EXISTS idx_user_sessions_os 
ON public.user_sessions (os_name, os_version);

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_user_sessions_device_info 
ON public.user_sessions USING gin (device_info);

CREATE INDEX IF NOT EXISTS idx_user_sessions_location_info 
ON public.user_sessions USING gin (location_info);

CREATE INDEX IF NOT EXISTS idx_user_sessions_metadata 
ON public.user_sessions USING gin (session_metadata);

CREATE INDEX IF NOT EXISTS idx_user_sessions_security_flags 
ON public.user_sessions USING gin (security_flags);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_active 
ON public.user_sessions (user_id, is_active, last_activity_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_type 
ON public.user_sessions (user_id, session_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_sessions_active_expires 
ON public.user_sessions (is_active, expires_at) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_device 
ON public.user_sessions (user_id, device_fingerprint, is_active);

-- Create partial indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_sessions_expired 
ON public.user_sessions (expires_at) 
WHERE is_active = true AND expires_at < now();

-- Add table and column comments
COMMENT ON TABLE public.user_sessions IS 'User session management with comprehensive security tracking and device monitoring';
COMMENT ON COLUMN public.user_sessions.id IS 'Unique identifier for the session';
COMMENT ON COLUMN public.user_sessions.user_id IS 'Reference to the user';
COMMENT ON COLUMN public.user_sessions.session_token IS 'Unique session token for authentication';
COMMENT ON COLUMN public.user_sessions.login_method IS 'Method used for authentication';
COMMENT ON COLUMN public.user_sessions.session_type IS 'Type of session (web, mobile, api, etc.)';
COMMENT ON COLUMN public.user_sessions.ip_address IS 'IP address of the client';
COMMENT ON COLUMN public.user_sessions.user_agent IS 'User agent string from the client';
COMMENT ON COLUMN public.user_sessions.device_info IS 'Device information and specifications';
COMMENT ON COLUMN public.user_sessions.location_info IS 'Geographic location information';
COMMENT ON COLUMN public.user_sessions.last_activity_at IS 'Timestamp of last session activity';
COMMENT ON COLUMN public.user_sessions.refresh_token IS 'Token for session refresh';
COMMENT ON COLUMN public.user_sessions.refresh_expires_at IS 'Expiration time for refresh token';
COMMENT ON COLUMN public.user_sessions.session_metadata IS 'Additional session metadata';
COMMENT ON COLUMN public.user_sessions.security_flags IS 'Security-related flags and indicators';
COMMENT ON COLUMN public.user_sessions.is_trusted_device IS 'Whether the device is marked as trusted';
COMMENT ON COLUMN public.user_sessions.device_fingerprint IS 'Unique device fingerprint';
COMMENT ON COLUMN public.user_sessions.two_factor_verified IS 'Whether two-factor authentication was completed';
COMMENT ON COLUMN public.user_sessions.session_duration_seconds IS 'Total session duration in seconds';
COMMENT ON COLUMN public.user_sessions.logout_reason IS 'Reason for session termination';
COMMENT ON COLUMN public.user_sessions.parent_session_id IS 'Parent session for linked sessions';
COMMENT ON COLUMN public.user_sessions.is_impersonation IS 'Whether this is an impersonation session';
COMMENT ON COLUMN public.user_sessions.impersonated_by IS 'User performing the impersonation';
COMMENT ON COLUMN public.user_sessions.browser_name IS 'Name of the browser';
COMMENT ON COLUMN public.user_sessions.browser_version IS 'Version of the browser';
COMMENT ON COLUMN public.user_sessions.os_name IS 'Operating system name';
COMMENT ON COLUMN public.user_sessions.os_version IS 'Operating system version';
COMMENT ON COLUMN public.user_sessions.is_mobile IS 'Whether the session is from a mobile device';
COMMENT ON COLUMN public.user_sessions.timezone IS 'User timezone';
COMMENT ON COLUMN public.user_sessions.language_preference IS 'User language preference';

-- Create view for active sessions with user details
CREATE OR REPLACE VIEW active_user_sessions AS
SELECT 
    us.id,
    us.user_id,
    u.username,
    u.full_name as user_name,
    us.session_token,
    us.login_method,
    us.session_type,
    us.ip_address,
    us.device_fingerprint,
    us.browser_name,
    us.browser_version,
    us.os_name,
    us.is_mobile,
    us.is_trusted_device,
    us.two_factor_verified,
    us.last_activity_at,
    us.expires_at,
    us.created_at,
    EXTRACT(EPOCH FROM (now() - us.last_activity_at)) / 60 as minutes_since_activity,
    EXTRACT(EPOCH FROM (us.expires_at - now())) / 60 as minutes_until_expiry,
    us.device_info,
    us.location_info,
    us.security_flags
FROM user_sessions us
LEFT JOIN users u ON us.user_id = u.id
WHERE us.is_active = true 
  AND us.expires_at > now()
  AND us.ended_at IS NULL
ORDER BY us.last_activity_at DESC;

-- Create function to create a new session
CREATE OR REPLACE FUNCTION create_user_session(
    user_id_param UUID,
    session_token_param VARCHAR,
    login_method_param VARCHAR,
    session_type_param VARCHAR DEFAULT 'web',
    ip_address_param INET DEFAULT NULL,
    user_agent_param TEXT DEFAULT NULL,
    expires_in_seconds INTEGER DEFAULT 86400,
    device_info_param JSONB DEFAULT '{}',
    location_info_param JSONB DEFAULT '{}',
    is_trusted_device_param BOOLEAN DEFAULT false,
    device_fingerprint_param VARCHAR DEFAULT NULL,
    two_factor_verified_param BOOLEAN DEFAULT false
)
RETURNS UUID AS $$
DECLARE
    session_id UUID;
    expires_at_calculated TIMESTAMPTZ;
BEGIN
    expires_at_calculated := now() + (expires_in_seconds || ' seconds')::INTERVAL;
    
    INSERT INTO user_sessions (
        user_id,
        session_token,
        login_method,
        session_type,
        ip_address,
        user_agent,
        expires_at,
        device_info,
        location_info,
        is_trusted_device,
        device_fingerprint,
        two_factor_verified
    ) VALUES (
        user_id_param,
        session_token_param,
        login_method_param,
        session_type_param,
        ip_address_param,
        user_agent_param,
        expires_at_calculated,
        device_info_param,
        location_info_param,
        is_trusted_device_param,
        device_fingerprint_param,
        two_factor_verified_param
    ) RETURNING id INTO session_id;
    
    RETURN session_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update session activity
CREATE OR REPLACE FUNCTION update_session_activity(
    session_token_param VARCHAR,
    extend_expiry_seconds INTEGER DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    session_found BOOLEAN;
    new_expires_at TIMESTAMPTZ;
BEGIN
    -- Calculate new expiry time if extension is requested
    IF extend_expiry_seconds IS NOT NULL THEN
        new_expires_at := now() + (extend_expiry_seconds || ' seconds')::INTERVAL;
    END IF;
    
    UPDATE user_sessions 
    SET 
        last_activity_at = now(),
        expires_at = COALESCE(new_expires_at, expires_at)
    WHERE session_token = session_token_param 
      AND is_active = true 
      AND expires_at > now()
      AND ended_at IS NULL;
    
    GET DIAGNOSTICS session_found = FOUND;
    RETURN session_found;
END;
$$ LANGUAGE plpgsql;

-- Create function to end a session
CREATE OR REPLACE FUNCTION end_user_session(
    session_token_param VARCHAR,
    logout_reason_param VARCHAR DEFAULT 'user_logout'
)
RETURNS BOOLEAN AS $$
DECLARE
    session_found BOOLEAN;
    session_duration INTEGER;
BEGIN
    UPDATE user_sessions 
    SET 
        is_active = false,
        ended_at = now(),
        logout_reason = logout_reason_param,
        session_duration_seconds = EXTRACT(EPOCH FROM (now() - created_at))
    WHERE session_token = session_token_param 
      AND is_active = true;
    
    GET DIAGNOSTICS session_found = FOUND;
    RETURN session_found;
END;
$$ LANGUAGE plpgsql;

-- Create function to get user session statistics
CREATE OR REPLACE FUNCTION get_user_session_statistics(
    user_id_param UUID DEFAULT NULL,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_sessions BIGINT,
    active_sessions BIGINT,
    avg_session_duration_minutes DECIMAL,
    max_concurrent_sessions BIGINT,
    unique_devices BIGINT,
    unique_ip_addresses BIGINT,
    mobile_sessions BIGINT,
    trusted_device_sessions BIGINT,
    two_factor_sessions BIGINT,
    most_common_browser VARCHAR,
    most_common_os VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_sessions,
        COUNT(*) FILTER (WHERE is_active = true AND expires_at > now()) as active_sessions,
        AVG(session_duration_seconds) / 60 as avg_session_duration_minutes,
        (SELECT MAX(concurrent_count) FROM (
            SELECT COUNT(*) as concurrent_count
            FROM user_sessions s2
            WHERE (user_id_param IS NULL OR s2.user_id = user_id_param)
              AND s2.created_at <= us.created_at
              AND (s2.ended_at IS NULL OR s2.ended_at >= us.created_at)
            GROUP BY s2.created_at::DATE
        ) concurrent_sessions) as max_concurrent_sessions,
        COUNT(DISTINCT device_fingerprint) as unique_devices,
        COUNT(DISTINCT ip_address) as unique_ip_addresses,
        COUNT(*) FILTER (WHERE is_mobile = true) as mobile_sessions,
        COUNT(*) FILTER (WHERE is_trusted_device = true) as trusted_device_sessions,
        COUNT(*) FILTER (WHERE two_factor_verified = true) as two_factor_sessions,
        (SELECT browser_name FROM user_sessions 
         WHERE (user_id_param IS NULL OR user_id = user_id_param)
         AND browser_name IS NOT NULL
         AND (date_from IS NULL OR created_at >= date_from)
         AND (date_to IS NULL OR created_at <= date_to)
         GROUP BY browser_name ORDER BY COUNT(*) DESC LIMIT 1) as most_common_browser,
        (SELECT os_name FROM user_sessions 
         WHERE (user_id_param IS NULL OR user_id = user_id_param)
         AND os_name IS NOT NULL
         AND (date_from IS NULL OR created_at >= date_from)
         AND (date_to IS NULL OR created_at <= date_to)
         GROUP BY os_name ORDER BY COUNT(*) DESC LIMIT 1) as most_common_os
    FROM user_sessions us
    WHERE (user_id_param IS NULL OR user_id = user_id_param)
      AND (date_from IS NULL OR created_at >= date_from)
      AND (date_to IS NULL OR created_at <= date_to);
END;
$$ LANGUAGE plpgsql;

-- Create function to cleanup expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions(
    cleanup_days_old INTEGER DEFAULT 30
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- End expired active sessions
    UPDATE user_sessions 
    SET 
        is_active = false,
        ended_at = COALESCE(ended_at, now()),
        logout_reason = COALESCE(logout_reason, 'expired')
    WHERE is_active = true 
      AND expires_at < now();
    
    -- Delete old inactive sessions
    DELETE FROM user_sessions
    WHERE is_active = false 
      AND (ended_at < now() - (cleanup_days_old || ' days')::INTERVAL 
           OR (ended_at IS NULL AND expires_at < now() - (cleanup_days_old || ' days')::INTERVAL));
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to detect suspicious sessions
CREATE OR REPLACE FUNCTION detect_suspicious_sessions(
    hours_back INTEGER DEFAULT 24
)
RETURNS TABLE(
    session_id UUID,
    user_id UUID,
    username VARCHAR,
    suspicious_indicators TEXT[],
    risk_score INTEGER,
    session_details JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH session_analysis AS (
        SELECT 
            us.id,
            us.user_id,
            u.username,
            us.ip_address,
            us.device_fingerprint,
            us.login_method,
            us.created_at,
            us.location_info,
            us.device_info,
            -- Count sessions from same IP
            COUNT(*) OVER (PARTITION BY us.ip_address) as ip_session_count,
            -- Count sessions from same device
            COUNT(*) OVER (PARTITION BY us.device_fingerprint) as device_session_count,
            -- Check for rapid successive logins
            LAG(us.created_at) OVER (PARTITION BY us.user_id ORDER BY us.created_at) as prev_login
        FROM user_sessions us
        LEFT JOIN users u ON us.user_id = u.id
        WHERE us.created_at >= now() - (hours_back || ' hours')::INTERVAL
    )
    SELECT 
        sa.id as session_id,
        sa.user_id,
        sa.username,
        ARRAY_REMOVE(ARRAY[
            CASE WHEN sa.ip_session_count > 10 THEN 'high_ip_usage' END,
            CASE WHEN sa.device_session_count > 5 THEN 'high_device_usage' END,
            CASE WHEN sa.prev_login IS NOT NULL AND sa.created_at - sa.prev_login < INTERVAL '1 minute' 
                 THEN 'rapid_successive_logins' END,
            CASE WHEN sa.location_info->>'country' IS NOT NULL AND 
                      sa.location_info->>'country' != 
                      (SELECT location_info->>'country' FROM user_sessions 
                       WHERE user_id = sa.user_id AND id != sa.id 
                       ORDER BY created_at DESC LIMIT 1)
                 THEN 'location_change' END
        ], NULL) as suspicious_indicators,
        CASE 
            WHEN sa.ip_session_count > 20 THEN 90
            WHEN sa.ip_session_count > 10 THEN 70
            WHEN sa.device_session_count > 10 THEN 60
            WHEN sa.prev_login IS NOT NULL AND sa.created_at - sa.prev_login < INTERVAL '30 seconds' THEN 80
            ELSE 20
        END as risk_score,
        jsonb_build_object(
            'ip_address', sa.ip_address,
            'device_fingerprint', sa.device_fingerprint,
            'login_method', sa.login_method,
            'created_at', sa.created_at,
            'ip_session_count', sa.ip_session_count,
            'device_session_count', sa.device_session_count
        ) as session_details
    FROM session_analysis sa
    WHERE ARRAY_LENGTH(ARRAY_REMOVE(ARRAY[
        CASE WHEN sa.ip_session_count > 10 THEN 'high_ip_usage' END,
        CASE WHEN sa.device_session_count > 5 THEN 'high_device_usage' END,
        CASE WHEN sa.prev_login IS NOT NULL AND sa.created_at - sa.prev_login < INTERVAL '1 minute' 
             THEN 'rapid_successive_logins' END
    ], NULL), 1) > 0
    ORDER BY risk_score DESC, sa.created_at DESC;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'user_sessions table created with comprehensive session management and security monitoring features';