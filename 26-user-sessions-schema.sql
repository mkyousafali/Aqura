-- =====================================================
-- Table: user_sessions
-- Description: User session management and tracking system
-- This table maintains active and historical user sessions for security and audit purposes
-- =====================================================

-- Create enum type for login methods (if not exists)
DO $$ BEGIN
    CREATE TYPE login_method_enum AS ENUM (
        'quick_access',
        'username_password',
        'sso',
        'api_key',
        'oauth',
        'two_factor'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create user_sessions table
CREATE TABLE public.user_sessions (
    -- Primary key with UUID generation using extensions
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    
    -- User identification
    user_id UUID NOT NULL,
    
    -- Session security data
    session_token CHARACTER VARYING(255) NOT NULL,
    login_method CHARACTER VARYING(20) NOT NULL,
    
    -- Connection information
    ip_address INET NULL,
    user_agent TEXT NULL,
    
    -- Session status and lifecycle
    is_active BOOLEAN NULL DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    ended_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Additional session metadata
    device_fingerprint TEXT NULL,
    location_country VARCHAR(3) NULL,
    location_city VARCHAR(100) NULL,
    session_duration_seconds INTEGER NULL,
    logout_reason VARCHAR(50) NULL,
    
    -- Primary key constraint
    CONSTRAINT user_sessions_pkey PRIMARY KEY (id),
    
    -- Unique constraint for session token
    CONSTRAINT user_sessions_session_token_key UNIQUE (session_token),
    
    -- Foreign key to users table with CASCADE delete
    CONSTRAINT user_sessions_user_id_fkey 
        FOREIGN KEY (user_id) 
        REFERENCES users (id) 
        ON DELETE CASCADE,
    
    -- Check constraint for login methods
    CONSTRAINT user_sessions_login_method_check 
        CHECK (
            login_method::text = ANY (
                ARRAY[
                    'quick_access'::character varying,
                    'username_password'::character varying,
                    'sso'::character varying,
                    'api_key'::character varying,
                    'oauth'::character varying,
                    'two_factor'::character varying
                ]::text[]
            )
        ),
    
    -- Check constraints for data integrity
    CONSTRAINT chk_session_token_not_empty 
        CHECK (length(trim(session_token)) > 0),
    
    CONSTRAINT chk_session_token_length 
        CHECK (length(session_token) >= 32 AND length(session_token) <= 255),
    
    -- Expiration must be in future when created
    CONSTRAINT chk_expires_at_future 
        CHECK (expires_at > created_at),
    
    -- Ended sessions must have ended_at timestamp
    CONSTRAINT chk_inactive_session_ended 
        CHECK (is_active = true OR ended_at IS NOT NULL),
    
    -- Session cannot end before it was created
    CONSTRAINT chk_ended_after_created 
        CHECK (ended_at IS NULL OR ended_at >= created_at),
    
    -- Session duration calculation consistency
    CONSTRAINT chk_session_duration_valid 
        CHECK (
            session_duration_seconds IS NULL OR 
            (session_duration_seconds >= 0 AND session_duration_seconds <= 86400 * 30)
        ),
    
    -- Location data validation
    CONSTRAINT chk_location_country_format 
        CHECK (location_country IS NULL OR length(location_country) = 2 OR length(location_country) = 3),
    
    -- Logout reason validation
    CONSTRAINT chk_logout_reason_valid 
        CHECK (
            logout_reason IS NULL OR 
            logout_reason IN (
                'user_logout', 'timeout', 'admin_terminate', 'security_violation',
                'password_change', 'account_locked', 'session_expired', 'device_change'
            )
        )
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Primary user lookup index
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id 
    ON public.user_sessions 
    USING btree (user_id) 
    TABLESPACE pg_default;

-- Session token lookup index (for authentication)
CREATE INDEX IF NOT EXISTS idx_user_sessions_token 
    ON public.user_sessions 
    USING btree (session_token) 
    TABLESPACE pg_default;

-- Active sessions index (for session management)
CREATE INDEX IF NOT EXISTS idx_user_sessions_active 
    ON public.user_sessions 
    USING btree (is_active) 
    TABLESPACE pg_default;

-- Composite index for active user sessions
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_active 
    ON public.user_sessions 
    USING btree (user_id, is_active, created_at DESC) 
    TABLESPACE pg_default;

-- Expiration index for cleanup operations
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at 
    ON public.user_sessions 
    USING btree (expires_at) 
    TABLESPACE pg_default;

-- Security monitoring indexes
CREATE INDEX IF NOT EXISTS idx_user_sessions_ip_address 
    ON public.user_sessions 
    USING btree (ip_address) 
    TABLESPACE pg_default
    WHERE ip_address IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_sessions_login_method 
    ON public.user_sessions 
    USING btree (login_method, created_at DESC) 
    TABLESPACE pg_default;

-- Recent sessions index for security analysis
CREATE INDEX IF NOT EXISTS idx_user_sessions_recent 
    ON public.user_sessions 
    USING btree (created_at DESC) 
    TABLESPACE pg_default
    WHERE created_at >= now() - INTERVAL '30 days';

-- Device fingerprint index for device tracking
CREATE INDEX IF NOT EXISTS idx_user_sessions_device_fingerprint 
    ON public.user_sessions 
    USING btree (device_fingerprint) 
    TABLESPACE pg_default
    WHERE device_fingerprint IS NOT NULL;

-- Location-based index for geographical analysis
CREATE INDEX IF NOT EXISTS idx_user_sessions_location 
    ON public.user_sessions 
    USING btree (location_country, location_city) 
    TABLESPACE pg_default
    WHERE location_country IS NOT NULL;

-- User agent analysis index
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_agent_search 
    ON public.user_sessions 
    USING gin (to_tsvector('english', user_agent)) 
    TABLESPACE pg_default
    WHERE user_agent IS NOT NULL;

-- =====================================================
-- Functions for Session Management
-- =====================================================

-- Function to create a new session
CREATE OR REPLACE FUNCTION create_user_session(
    p_user_id UUID,
    p_session_token VARCHAR(255),
    p_login_method VARCHAR(20),
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_device_fingerprint TEXT DEFAULT NULL,
    p_location_country VARCHAR(3) DEFAULT NULL,
    p_location_city VARCHAR(100) DEFAULT NULL,
    p_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    session_id UUID;
    default_expiry TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Set default expiry if not provided (24 hours)
    IF p_expires_at IS NULL THEN
        default_expiry := now() + INTERVAL '24 hours';
    ELSE
        default_expiry := p_expires_at;
    END IF;
    
    -- Insert new session
    INSERT INTO public.user_sessions (
        user_id, session_token, login_method, ip_address, user_agent,
        device_fingerprint, location_country, location_city, expires_at
    ) VALUES (
        p_user_id, p_session_token, p_login_method, p_ip_address, p_user_agent,
        p_device_fingerprint, p_location_country, p_location_city, default_expiry
    )
    RETURNING id INTO session_id;
    
    RETURN session_id;
END;
$$ LANGUAGE plpgsql;

-- Function to validate and get session
CREATE OR REPLACE FUNCTION get_valid_session(
    p_session_token VARCHAR(255)
)
RETURNS TABLE (
    session_id UUID,
    user_id UUID,
    login_method VARCHAR,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE,
    is_expired BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        us.id as session_id,
        us.user_id,
        us.login_method,
        us.ip_address,
        us.user_agent,
        us.expires_at,
        us.created_at,
        (us.expires_at < now()) as is_expired
    FROM public.user_sessions us
    WHERE us.session_token = p_session_token
      AND us.is_active = true;
END;
$$ LANGUAGE plpgsql;

-- Function to end a session
CREATE OR REPLACE FUNCTION end_user_session(
    p_session_token VARCHAR(255),
    p_logout_reason VARCHAR(50) DEFAULT 'user_logout'
)
RETURNS BOOLEAN AS $$
DECLARE
    session_record RECORD;
    duration_seconds INTEGER;
BEGIN
    -- Get session information
    SELECT * INTO session_record
    FROM public.user_sessions
    WHERE session_token = p_session_token AND is_active = true;
    
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    -- Calculate session duration
    duration_seconds := EXTRACT(EPOCH FROM (now() - session_record.created_at))::INTEGER;
    
    -- Update session
    UPDATE public.user_sessions
    SET 
        is_active = false,
        ended_at = now(),
        logout_reason = p_logout_reason,
        session_duration_seconds = duration_seconds
    WHERE session_token = p_session_token;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    -- End expired but still active sessions
    UPDATE public.user_sessions
    SET 
        is_active = false,
        ended_at = now(),
        logout_reason = 'session_expired',
        session_duration_seconds = EXTRACT(EPOCH FROM (expires_at - created_at))::INTEGER
    WHERE is_active = true 
      AND expires_at < now();
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get user active sessions
CREATE OR REPLACE FUNCTION get_user_active_sessions(
    p_user_id UUID
)
RETURNS TABLE (
    session_id UUID,
    session_token VARCHAR,
    login_method VARCHAR,
    ip_address INET,
    user_agent TEXT,
    device_fingerprint TEXT,
    location_country VARCHAR,
    location_city VARCHAR,
    created_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    is_current_device BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        us.id as session_id,
        us.session_token,
        us.login_method,
        us.ip_address,
        us.user_agent,
        us.device_fingerprint,
        us.location_country,
        us.location_city,
        us.created_at,
        us.expires_at,
        (us.created_at = (
            SELECT MAX(us2.created_at)
            FROM public.user_sessions us2
            WHERE us2.user_id = p_user_id AND us2.is_active = true
        )) as is_current_device
    FROM public.user_sessions us
    WHERE us.user_id = p_user_id 
      AND us.is_active = true
      AND us.expires_at > now()
    ORDER BY us.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to terminate all user sessions (except current)
CREATE OR REPLACE FUNCTION terminate_user_sessions(
    p_user_id UUID,
    p_except_session_token VARCHAR(255) DEFAULT NULL,
    p_logout_reason VARCHAR(50) DEFAULT 'admin_terminate'
)
RETURNS INTEGER AS $$
DECLARE
    terminated_count INTEGER;
BEGIN
    -- End all active sessions for user except the specified one
    UPDATE public.user_sessions
    SET 
        is_active = false,
        ended_at = now(),
        logout_reason = p_logout_reason,
        session_duration_seconds = EXTRACT(EPOCH FROM (now() - created_at))::INTEGER
    WHERE user_id = p_user_id 
      AND is_active = true
      AND (p_except_session_token IS NULL OR session_token != p_except_session_token);
    
    GET DIAGNOSTICS terminated_count = ROW_COUNT;
    
    RETURN terminated_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get session statistics
CREATE OR REPLACE FUNCTION get_session_statistics(
    p_user_id UUID DEFAULT NULL,
    p_days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
    total_sessions BIGINT,
    active_sessions BIGINT,
    avg_session_duration_minutes NUMERIC,
    unique_ips BIGINT,
    unique_devices BIGINT,
    login_methods JSONB,
    top_locations JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_sessions,
        COUNT(CASE WHEN us.is_active = true THEN 1 END) as active_sessions,
        ROUND(AVG(us.session_duration_seconds) / 60.0, 2) as avg_session_duration_minutes,
        COUNT(DISTINCT us.ip_address) as unique_ips,
        COUNT(DISTINCT us.device_fingerprint) as unique_devices,
        (
            SELECT jsonb_object_agg(login_method, method_count)
            FROM (
                SELECT login_method, COUNT(*) as method_count
                FROM public.user_sessions
                WHERE (p_user_id IS NULL OR user_id = p_user_id)
                  AND created_at >= now() - (p_days_back || ' days')::INTERVAL
                GROUP BY login_method
            ) methods
        ) as login_methods,
        (
            SELECT jsonb_object_agg(location_key, location_count)
            FROM (
                SELECT 
                    COALESCE(location_country || '-' || location_city, 'Unknown') as location_key,
                    COUNT(*) as location_count
                FROM public.user_sessions
                WHERE (p_user_id IS NULL OR user_id = p_user_id)
                  AND created_at >= now() - (p_days_back || ' days')::INTERVAL
                GROUP BY location_country, location_city
                ORDER BY location_count DESC
                LIMIT 10
            ) locations
        ) as top_locations
    FROM public.user_sessions us
    WHERE (p_user_id IS NULL OR us.user_id = p_user_id)
      AND us.created_at >= now() - (p_days_back || ' days')::INTERVAL;
END;
$$ LANGUAGE plpgsql;

-- Function to detect suspicious sessions
CREATE OR REPLACE FUNCTION detect_suspicious_sessions(
    p_user_id UUID DEFAULT NULL,
    p_hours_back INTEGER DEFAULT 24
)
RETURNS TABLE (
    session_id UUID,
    user_id UUID,
    ip_address INET,
    location_country VARCHAR,
    login_method VARCHAR,
    created_at TIMESTAMP WITH TIME ZONE,
    risk_factors TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    WITH session_analysis AS (
        SELECT 
            us.id,
            us.user_id,
            us.ip_address,
            us.location_country,
            us.login_method,
            us.created_at,
            -- Risk factor analysis
            CASE WHEN COUNT(*) OVER (
                PARTITION BY us.user_id, us.ip_address 
                ORDER BY us.created_at 
                RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW
            ) > 5 THEN 'multiple_attempts_same_ip' END as risk_1,
            
            CASE WHEN COUNT(DISTINCT us.ip_address) OVER (
                PARTITION BY us.user_id 
                ORDER BY us.created_at 
                RANGE BETWEEN INTERVAL '1 hour' PRECEDING AND CURRENT ROW
            ) > 3 THEN 'multiple_ips_short_time' END as risk_2,
            
            CASE WHEN us.location_country != LAG(us.location_country) OVER (
                PARTITION BY us.user_id ORDER BY us.created_at
            ) AND LAG(us.created_at) OVER (
                PARTITION BY us.user_id ORDER BY us.created_at
            ) > us.created_at - INTERVAL '30 minutes' THEN 'impossible_travel' END as risk_3,
            
            CASE WHEN us.login_method = 'quick_access' AND COUNT(*) OVER (
                PARTITION BY us.user_id 
                ORDER BY us.created_at 
                RANGE BETWEEN INTERVAL '5 minutes' PRECEDING AND CURRENT ROW
            ) > 10 THEN 'rapid_quick_access' END as risk_4
            
        FROM public.user_sessions us
        WHERE (p_user_id IS NULL OR us.user_id = p_user_id)
          AND us.created_at >= now() - (p_hours_back || ' hours')::INTERVAL
    )
    SELECT 
        sa.id as session_id,
        sa.user_id,
        sa.ip_address,
        sa.location_country,
        sa.login_method,
        sa.created_at,
        ARRAY_REMOVE(ARRAY[sa.risk_1, sa.risk_2, sa.risk_3, sa.risk_4], NULL) as risk_factors
    FROM session_analysis sa
    WHERE ARRAY_REMOVE(ARRAY[sa.risk_1, sa.risk_2, sa.risk_3, sa.risk_4], NULL) != '{}';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Triggers for Session Management
-- =====================================================

-- Trigger function for session validation and maintenance
CREATE OR REPLACE FUNCTION trigger_session_maintenance()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-calculate session duration when ending session
    IF TG_OP = 'UPDATE' AND OLD.is_active = true AND NEW.is_active = false THEN
        NEW.ended_at := COALESCE(NEW.ended_at, now());
        NEW.session_duration_seconds := COALESCE(
            NEW.session_duration_seconds,
            EXTRACT(EPOCH FROM (NEW.ended_at - NEW.created_at))::INTEGER
        );
    END IF;
    
    -- Validate session token format (should be cryptographically secure)
    IF TG_OP = 'INSERT' AND (LENGTH(NEW.session_token) < 32 OR NEW.session_token !~ '^[A-Za-z0-9+/=_-]+$') THEN
        RAISE EXCEPTION 'Session token must be at least 32 characters and contain only valid characters';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create session maintenance trigger
CREATE TRIGGER trigger_session_maintenance
    BEFORE INSERT OR UPDATE ON public.user_sessions
    FOR EACH ROW
    EXECUTE FUNCTION trigger_session_maintenance();

-- =====================================================
-- Views for Session Analysis
-- =====================================================

-- View for active sessions overview
CREATE OR REPLACE VIEW active_sessions_overview AS
SELECT 
    us.id,
    us.user_id,
    u.email as user_email,
    u.full_name as user_name,
    us.login_method,
    us.ip_address,
    us.location_country,
    us.location_city,
    us.created_at,
    us.expires_at,
    EXTRACT(HOURS FROM (us.expires_at - now()))::INTEGER as hours_until_expiry,
    us.device_fingerprint,
    CASE 
        WHEN us.expires_at < now() THEN 'EXPIRED'
        WHEN us.expires_at < now() + INTERVAL '1 hour' THEN 'EXPIRING_SOON'
        ELSE 'ACTIVE'
    END as status
FROM public.user_sessions us
JOIN public.users u ON us.user_id = u.id
WHERE us.is_active = true;

-- View for session security monitoring
CREATE OR REPLACE VIEW session_security_monitor AS
SELECT 
    us.user_id,
    u.email as user_email,
    COUNT(*) as total_sessions,
    COUNT(DISTINCT us.ip_address) as unique_ips,
    COUNT(DISTINCT us.device_fingerprint) as unique_devices,
    COUNT(DISTINCT us.location_country) as unique_countries,
    MAX(us.created_at) as last_session,
    MIN(us.created_at) as first_session,
    AVG(us.session_duration_seconds) / 60 as avg_session_minutes,
    COUNT(CASE WHEN us.created_at >= now() - INTERVAL '24 hours' THEN 1 END) as sessions_last_24h,
    COUNT(CASE WHEN us.logout_reason = 'security_violation' THEN 1 END) as security_violations
FROM public.user_sessions us
JOIN public.users u ON us.user_id = u.id
WHERE us.created_at >= now() - INTERVAL '30 days'
GROUP BY us.user_id, u.email
ORDER BY sessions_last_24h DESC, security_violations DESC;

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.user_sessions IS 'User session management and tracking system - maintains active and historical user sessions for security and audit purposes';

COMMENT ON COLUMN public.user_sessions.id IS 'Primary key - unique identifier for each session';
COMMENT ON COLUMN public.user_sessions.user_id IS 'Foreign key to users table - which user this session belongs to';
COMMENT ON COLUMN public.user_sessions.session_token IS 'Unique session token for authentication (cryptographically secure)';
COMMENT ON COLUMN public.user_sessions.login_method IS 'Method used to authenticate (quick_access, username_password, sso, etc.)';
COMMENT ON COLUMN public.user_sessions.ip_address IS 'IP address from which the session was initiated';
COMMENT ON COLUMN public.user_sessions.user_agent IS 'Browser/client user agent string for device identification';
COMMENT ON COLUMN public.user_sessions.is_active IS 'Flag indicating if the session is currently active';
COMMENT ON COLUMN public.user_sessions.expires_at IS 'Timestamp when the session expires';
COMMENT ON COLUMN public.user_sessions.created_at IS 'Timestamp when the session was created';
COMMENT ON COLUMN public.user_sessions.ended_at IS 'Timestamp when the session was ended (logout/expiry)';
COMMENT ON COLUMN public.user_sessions.device_fingerprint IS 'Unique device fingerprint for device tracking';
COMMENT ON COLUMN public.user_sessions.location_country IS 'Country code where the session originated';
COMMENT ON COLUMN public.user_sessions.location_city IS 'City where the session originated';
COMMENT ON COLUMN public.user_sessions.session_duration_seconds IS 'Total session duration in seconds (calculated on end)';
COMMENT ON COLUMN public.user_sessions.logout_reason IS 'Reason for session termination (user_logout, timeout, security_violation, etc.)';

-- Index comments
COMMENT ON INDEX idx_user_sessions_user_id IS 'Primary user lookup index for session management queries';
COMMENT ON INDEX idx_user_sessions_token IS 'Session token lookup index for authentication requests';
COMMENT ON INDEX idx_user_sessions_active IS 'Active sessions index for session management operations';
COMMENT ON INDEX idx_user_sessions_user_active IS 'Composite index for user active sessions with chronological ordering';

-- Function comments
COMMENT ON FUNCTION create_user_session(UUID, VARCHAR, VARCHAR, INET, TEXT, TEXT, VARCHAR, VARCHAR, TIMESTAMP WITH TIME ZONE) IS 'Creates a new user session with comprehensive metadata tracking';
COMMENT ON FUNCTION get_valid_session(VARCHAR) IS 'Validates and retrieves session information for authentication';
COMMENT ON FUNCTION end_user_session(VARCHAR, VARCHAR) IS 'Ends a user session with proper cleanup and duration calculation';
COMMENT ON FUNCTION cleanup_expired_sessions() IS 'Maintenance function to clean up expired sessions automatically';
COMMENT ON FUNCTION detect_suspicious_sessions(UUID, INTEGER) IS 'Security function to identify potentially suspicious session patterns';

-- View comments
COMMENT ON VIEW active_sessions_overview IS 'Administrative view of all active sessions with user information and expiry status';
COMMENT ON VIEW session_security_monitor IS 'Security monitoring view for session analysis and threat detection';