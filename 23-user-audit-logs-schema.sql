-- =====================================================
-- Table: user_audit_logs
-- Description: User audit logging and activity tracking system
-- This table tracks all user-related actions for security, compliance, and monitoring
-- =====================================================

-- Create enum types for user audit logs
CREATE TYPE public.audit_action_category_enum AS ENUM (
    'authentication',
    'authorization',
    'data_access',
    'data_modification',
    'user_management',
    'system_administration',
    'security_event',
    'compliance_action'
);

CREATE TYPE public.audit_severity_enum AS ENUM (
    'low',
    'medium',
    'high',
    'critical'
);

-- Create user_audit_logs table
CREATE TABLE public.user_audit_logs (
    -- Primary key with UUID generation using extensions
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    
    -- User identification
    user_id UUID NULL,
    target_user_id UUID NULL,
    
    -- Action details
    action CHARACTER VARYING(100) NOT NULL,
    table_name CHARACTER VARYING(100) NULL,
    record_id UUID NULL,
    
    -- Data change tracking
    old_values JSONB NULL,
    new_values JSONB NULL,
    
    -- Session and context information
    ip_address INET NULL,
    user_agent TEXT NULL,
    performed_by UUID NULL,
    
    -- Audit timestamp
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    -- Primary key constraint
    CONSTRAINT user_audit_logs_pkey PRIMARY KEY (id),
    
    -- Foreign key constraints with appropriate handling
    CONSTRAINT user_audit_logs_user_id_fkey 
        FOREIGN KEY (user_id) 
        REFERENCES users (id) 
        ON DELETE SET NULL,
    
    CONSTRAINT user_audit_logs_target_user_id_fkey 
        FOREIGN KEY (target_user_id) 
        REFERENCES users (id) 
        ON DELETE SET NULL,
    
    CONSTRAINT user_audit_logs_performed_by_fkey 
        FOREIGN KEY (performed_by) 
        REFERENCES users (id),
    
    -- Check constraints for data integrity
    CONSTRAINT chk_action_not_empty 
        CHECK (length(trim(action)) > 0),
    
    -- Check constraint for logical user relationships
    CONSTRAINT chk_user_relationships_logical 
        CHECK (
            user_id IS NOT NULL OR target_user_id IS NOT NULL OR performed_by IS NOT NULL
        ),
    
    -- Check constraint for data modification actions
    CONSTRAINT chk_data_modification_consistency 
        CHECK (
            (action NOT LIKE '%UPDATE%' AND action NOT LIKE '%MODIFY%') OR 
            (old_values IS NOT NULL OR new_values IS NOT NULL)
        )
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Primary lookup indexes
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_user_id 
    ON public.user_audit_logs 
    USING btree (user_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_target_user_id 
    ON public.user_audit_logs 
    USING btree (target_user_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_performed_by 
    ON public.user_audit_logs 
    USING btree (performed_by) 
    TABLESPACE pg_default;

-- Action and table tracking indexes
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_action 
    ON public.user_audit_logs 
    USING btree (action) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_table_name 
    ON public.user_audit_logs 
    USING btree (table_name) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_record_id 
    ON public.user_audit_logs 
    USING btree (record_id) 
    TABLESPACE pg_default;

-- Temporal indexes
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_created_at 
    ON public.user_audit_logs 
    USING btree (created_at DESC) 
    TABLESPACE pg_default;

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_user_timeline 
    ON public.user_audit_logs 
    USING btree (user_id, created_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_action_timeline 
    ON public.user_audit_logs 
    USING btree (action, created_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_table_timeline 
    ON public.user_audit_logs 
    USING btree (table_name, created_at DESC) 
    TABLESPACE pg_default
    WHERE table_name IS NOT NULL;

-- Security and monitoring indexes
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_ip_address 
    ON public.user_audit_logs 
    USING btree (ip_address) 
    TABLESPACE pg_default
    WHERE ip_address IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_session_tracking 
    ON public.user_audit_logs 
    USING btree (user_id, ip_address, created_at DESC) 
    TABLESPACE pg_default
    WHERE ip_address IS NOT NULL;

-- JSONB indexes for data change analysis
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_old_values_gin 
    ON public.user_audit_logs 
    USING gin (old_values) 
    TABLESPACE pg_default
    WHERE old_values IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_new_values_gin 
    ON public.user_audit_logs 
    USING gin (new_values) 
    TABLESPACE pg_default
    WHERE new_values IS NOT NULL;

-- Security event detection indexes
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_security_events 
    ON public.user_audit_logs 
    USING btree (action, ip_address, created_at DESC) 
    TABLESPACE pg_default
    WHERE action IN ('LOGIN_FAILED', 'PERMISSION_DENIED', 'UNAUTHORIZED_ACCESS', 'SUSPICIOUS_ACTIVITY');

-- Record modification tracking index
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_record_tracking 
    ON public.user_audit_logs 
    USING btree (table_name, record_id, created_at DESC) 
    TABLESPACE pg_default
    WHERE table_name IS NOT NULL AND record_id IS NOT NULL;

-- =====================================================
-- Functions for Audit Logging
-- =====================================================

-- Function to log user action
CREATE OR REPLACE FUNCTION log_user_action(
    p_user_id UUID DEFAULT NULL,
    p_action VARCHAR(100),
    p_table_name VARCHAR(100) DEFAULT NULL,
    p_record_id UUID DEFAULT NULL,
    p_old_values JSONB DEFAULT NULL,
    p_new_values JSONB DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_performed_by UUID DEFAULT NULL,
    p_target_user_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    log_id UUID;
BEGIN
    INSERT INTO public.user_audit_logs (
        user_id, action, table_name, record_id, old_values, new_values,
        ip_address, user_agent, performed_by, target_user_id
    ) VALUES (
        p_user_id, p_action, p_table_name, p_record_id, p_old_values, p_new_values,
        p_ip_address, p_user_agent, p_performed_by, p_target_user_id
    )
    RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get user activity timeline
CREATE OR REPLACE FUNCTION get_user_activity_timeline(
    p_user_id UUID,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    log_id UUID,
    action VARCHAR,
    table_name VARCHAR,
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ual.id as log_id,
        ual.action,
        ual.table_name,
        ual.record_id,
        ual.old_values,
        ual.new_values,
        ual.ip_address,
        ual.created_at
    FROM public.user_audit_logs ual
    WHERE ual.user_id = p_user_id
      AND (p_start_date IS NULL OR ual.created_at >= p_start_date)
      AND (p_end_date IS NULL OR ual.created_at <= p_end_date)
    ORDER BY ual.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to detect suspicious activity
CREATE OR REPLACE FUNCTION detect_suspicious_activity(
    p_user_id UUID DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_time_window_hours INTEGER DEFAULT 24
)
RETURNS TABLE (
    user_id UUID,
    ip_address INET,
    failed_login_count BIGINT,
    permission_denied_count BIGINT,
    unusual_access_count BIGINT,
    first_event TIMESTAMP WITH TIME ZONE,
    last_event TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ual.user_id,
        ual.ip_address,
        COUNT(CASE WHEN ual.action LIKE '%LOGIN_FAILED%' THEN 1 END) as failed_login_count,
        COUNT(CASE WHEN ual.action LIKE '%PERMISSION_DENIED%' THEN 1 END) as permission_denied_count,
        COUNT(CASE WHEN ual.action LIKE '%UNAUTHORIZED%' OR ual.action LIKE '%SUSPICIOUS%' THEN 1 END) as unusual_access_count,
        MIN(ual.created_at) as first_event,
        MAX(ual.created_at) as last_event
    FROM public.user_audit_logs ual
    WHERE ual.created_at >= now() - (p_time_window_hours || ' hours')::INTERVAL
      AND (p_user_id IS NULL OR ual.user_id = p_user_id)
      AND (p_ip_address IS NULL OR ual.ip_address = p_ip_address)
      AND ual.action IN ('LOGIN_FAILED', 'PERMISSION_DENIED', 'UNAUTHORIZED_ACCESS', 'SUSPICIOUS_ACTIVITY')
    GROUP BY ual.user_id, ual.ip_address
    HAVING COUNT(*) > 3
    ORDER BY COUNT(*) DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get audit statistics
CREATE OR REPLACE FUNCTION get_audit_statistics(
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS TABLE (
    total_events BIGINT,
    unique_users BIGINT,
    unique_ip_addresses BIGINT,
    top_actions JSONB,
    events_by_hour JSONB,
    security_events BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_events,
        COUNT(DISTINCT ual.user_id) as unique_users,
        COUNT(DISTINCT ual.ip_address) as unique_ip_addresses,
        jsonb_object_agg(action_stats.action, action_stats.count) as top_actions,
        jsonb_object_agg(hour_stats.hour, hour_stats.count) as events_by_hour,
        COUNT(CASE WHEN ual.action IN ('LOGIN_FAILED', 'PERMISSION_DENIED', 'UNAUTHORIZED_ACCESS') THEN 1 END) as security_events
    FROM public.user_audit_logs ual
    LEFT JOIN (
        SELECT action, COUNT(*) as count
        FROM public.user_audit_logs
        WHERE (p_start_date IS NULL OR created_at >= p_start_date)
          AND (p_end_date IS NULL OR created_at <= p_end_date)
        GROUP BY action
        ORDER BY COUNT(*) DESC
        LIMIT 10
    ) action_stats ON true
    LEFT JOIN (
        SELECT EXTRACT(HOUR FROM created_at) as hour, COUNT(*) as count
        FROM public.user_audit_logs
        WHERE (p_start_date IS NULL OR created_at >= p_start_date)
          AND (p_end_date IS NULL OR created_at <= p_end_date)
        GROUP BY EXTRACT(HOUR FROM created_at)
    ) hour_stats ON true
    WHERE (p_start_date IS NULL OR ual.created_at >= p_start_date)
      AND (p_end_date IS NULL OR ual.created_at <= p_end_date);
END;
$$ LANGUAGE plpgsql;

-- Function to search audit logs by criteria
CREATE OR REPLACE FUNCTION search_audit_logs(
    p_user_id UUID DEFAULT NULL,
    p_action_pattern TEXT DEFAULT NULL,
    p_table_name VARCHAR DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    log_id UUID,
    user_id UUID,
    action VARCHAR,
    table_name VARCHAR,
    record_id UUID,
    ip_address INET,
    created_at TIMESTAMP WITH TIME ZONE,
    old_values JSONB,
    new_values JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ual.id as log_id,
        ual.user_id,
        ual.action,
        ual.table_name,
        ual.record_id,
        ual.ip_address,
        ual.created_at,
        ual.old_values,
        ual.new_values
    FROM public.user_audit_logs ual
    WHERE (p_user_id IS NULL OR ual.user_id = p_user_id)
      AND (p_action_pattern IS NULL OR ual.action ILIKE '%' || p_action_pattern || '%')
      AND (p_table_name IS NULL OR ual.table_name = p_table_name)
      AND (p_ip_address IS NULL OR ual.ip_address = p_ip_address)
      AND (p_start_date IS NULL OR ual.created_at >= p_start_date)
      AND (p_end_date IS NULL OR ual.created_at <= p_end_date)
    ORDER BY ual.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function for audit log cleanup (data retention)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs(
    p_retention_days INTEGER DEFAULT 365
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM public.user_audit_logs 
    WHERE created_at < now() - (p_retention_days || ' days')::INTERVAL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Views for Common Audit Queries
-- =====================================================

-- View for recent user activities
CREATE OR REPLACE VIEW recent_user_activities AS
SELECT 
    ual.id,
    ual.user_id,
    u.email as user_email,
    ual.action,
    ual.table_name,
    ual.record_id,
    ual.ip_address,
    ual.created_at,
    CASE 
        WHEN ual.action IN ('LOGIN_FAILED', 'PERMISSION_DENIED', 'UNAUTHORIZED_ACCESS') THEN 'security'
        WHEN ual.action LIKE '%LOGIN%' OR ual.action LIKE '%LOGOUT%' THEN 'authentication'
        WHEN ual.action LIKE '%CREATE%' OR ual.action LIKE '%UPDATE%' OR ual.action LIKE '%DELETE%' THEN 'data_modification'
        ELSE 'general'
    END as event_category
FROM public.user_audit_logs ual
LEFT JOIN public.users u ON ual.user_id = u.id
WHERE ual.created_at >= now() - INTERVAL '24 hours'
ORDER BY ual.created_at DESC;

-- View for security events summary
CREATE OR REPLACE VIEW security_events_summary AS
SELECT 
    ual.user_id,
    u.email as user_email,
    ual.ip_address,
    ual.action,
    COUNT(*) as event_count,
    MIN(ual.created_at) as first_occurrence,
    MAX(ual.created_at) as last_occurrence
FROM public.user_audit_logs ual
LEFT JOIN public.users u ON ual.user_id = u.id
WHERE ual.action IN ('LOGIN_FAILED', 'PERMISSION_DENIED', 'UNAUTHORIZED_ACCESS', 'SUSPICIOUS_ACTIVITY')
  AND ual.created_at >= now() - INTERVAL '7 days'
GROUP BY ual.user_id, u.email, ual.ip_address, ual.action
ORDER BY event_count DESC, last_occurrence DESC;

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.user_audit_logs IS 'User audit logging and activity tracking system for security, compliance, and monitoring';

COMMENT ON COLUMN public.user_audit_logs.id IS 'Primary key - unique identifier for each audit log entry';
COMMENT ON COLUMN public.user_audit_logs.user_id IS 'Foreign key to users table - user who performed the action (nullable for system actions)';
COMMENT ON COLUMN public.user_audit_logs.target_user_id IS 'Foreign key to users table - user who was the target of the action (for user management actions)';
COMMENT ON COLUMN public.user_audit_logs.action IS 'Description of the action performed (LOGIN, CREATE_USER, UPDATE_PROFILE, etc.)';
COMMENT ON COLUMN public.user_audit_logs.table_name IS 'Database table affected by the action (for data modification actions)';
COMMENT ON COLUMN public.user_audit_logs.record_id IS 'Primary key of the affected record (for data modification actions)';
COMMENT ON COLUMN public.user_audit_logs.old_values IS 'JSONB object containing the previous values before modification';
COMMENT ON COLUMN public.user_audit_logs.new_values IS 'JSONB object containing the new values after modification';
COMMENT ON COLUMN public.user_audit_logs.ip_address IS 'IP address from which the action was performed';
COMMENT ON COLUMN public.user_audit_logs.user_agent IS 'Browser/client user agent string';
COMMENT ON COLUMN public.user_audit_logs.performed_by IS 'Foreign key to users table - user who initiated the action (for administrative actions)';
COMMENT ON COLUMN public.user_audit_logs.created_at IS 'Timestamp when the action was performed';

-- Function comments
COMMENT ON FUNCTION log_user_action(UUID, VARCHAR, VARCHAR, UUID, JSONB, JSONB, INET, TEXT, UUID, UUID) IS 'Logs a user action with comprehensive context and metadata';
COMMENT ON FUNCTION get_user_activity_timeline(UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, INTEGER) IS 'Returns chronological timeline of user activities with optional date filtering';
COMMENT ON FUNCTION detect_suspicious_activity(UUID, INET, INTEGER) IS 'Analyzes audit logs to detect patterns indicating suspicious or malicious activity';
COMMENT ON FUNCTION get_audit_statistics(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) IS 'Provides comprehensive audit statistics and analytics for reporting';
COMMENT ON FUNCTION cleanup_old_audit_logs(INTEGER) IS 'Data retention function to remove old audit logs based on retention policy';

-- View comments
COMMENT ON VIEW recent_user_activities IS 'Real-time view of recent user activities with event categorization';
COMMENT ON VIEW security_events_summary IS 'Summary view of security-related events for monitoring and alerting';