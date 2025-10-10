-- Create user_audit_logs table for comprehensive audit trail of user actions
-- This table tracks all user activities, changes, and system interactions

-- Create the user_audit_logs table
CREATE TABLE IF NOT EXISTS public.user_audit_logs (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NULL,
    target_user_id UUID NULL,
    action CHARACTER VARYING(100) NOT NULL,
    table_name CHARACTER VARYING(100) NULL,
    record_id UUID NULL,
    old_values JSONB NULL,
    new_values JSONB NULL,
    ip_address INET NULL,
    user_agent TEXT NULL,
    performed_by UUID NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT user_audit_logs_pkey PRIMARY KEY (id),
    CONSTRAINT user_audit_logs_performed_by_fkey 
        FOREIGN KEY (performed_by) REFERENCES users (id),
    CONSTRAINT user_audit_logs_target_user_id_fkey 
        FOREIGN KEY (target_user_id) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT user_audit_logs_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
) TABLESPACE pg_default;

-- Create indexes for efficient queries (original indexes)
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_user_id 
ON public.user_audit_logs USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_action 
ON public.user_audit_logs USING btree (action) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_created_at 
ON public.user_audit_logs USING btree (created_at) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_target_user_id 
ON public.user_audit_logs (target_user_id);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_performed_by 
ON public.user_audit_logs (performed_by);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_table_name 
ON public.user_audit_logs (table_name);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_record_id 
ON public.user_audit_logs (record_id);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_ip_address 
ON public.user_audit_logs (ip_address);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_user_action 
ON public.user_audit_logs (user_id, action);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_table_record 
ON public.user_audit_logs (table_name, record_id);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_action_date 
ON public.user_audit_logs (action, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_user_date 
ON public.user_audit_logs (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_target_date 
ON public.user_audit_logs (target_user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_performed_by_date 
ON public.user_audit_logs (performed_by, created_at DESC);

-- Create partial indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_data_changes 
ON public.user_audit_logs (created_at DESC) 
WHERE old_values IS NOT NULL OR new_values IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_login_actions 
ON public.user_audit_logs (created_at DESC) 
WHERE action IN ('login', 'logout', 'login_failed');

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_admin_actions 
ON public.user_audit_logs (created_at DESC) 
WHERE action IN ('user_created', 'user_updated', 'user_deleted', 'role_changed', 'permission_granted', 'permission_revoked');

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_old_values 
ON public.user_audit_logs USING gin (old_values);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_new_values 
ON public.user_audit_logs USING gin (new_values);

-- Add additional columns for enhanced functionality
ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS session_id VARCHAR(255);

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS request_id VARCHAR(255);

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS api_endpoint VARCHAR(500);

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS http_method VARCHAR(10);

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS response_status INTEGER;

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS duration_ms INTEGER;

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS error_message TEXT;

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS severity VARCHAR(20) DEFAULT 'info';

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS category VARCHAR(50);

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS device_info JSONB DEFAULT '{}';

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS location_info JSONB DEFAULT '{}';

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS additional_data JSONB DEFAULT '{}';

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS is_suspicious BOOLEAN DEFAULT false;

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS risk_score INTEGER DEFAULT 0;

ALTER TABLE public.user_audit_logs 
ADD COLUMN IF NOT EXISTS tags TEXT[];

-- Add validation constraints
ALTER TABLE public.user_audit_logs 
ADD CONSTRAINT chk_action_not_empty 
CHECK (TRIM(action) != '');

ALTER TABLE public.user_audit_logs 
ADD CONSTRAINT chk_severity_valid 
CHECK (severity IN ('debug', 'info', 'warning', 'error', 'critical'));

ALTER TABLE public.user_audit_logs 
ADD CONSTRAINT chk_http_method_valid 
CHECK (http_method IS NULL OR http_method IN ('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS', 'HEAD'));

ALTER TABLE public.user_audit_logs 
ADD CONSTRAINT chk_response_status_valid 
CHECK (response_status IS NULL OR (response_status >= 100 AND response_status <= 599));

ALTER TABLE public.user_audit_logs 
ADD CONSTRAINT chk_duration_non_negative 
CHECK (duration_ms IS NULL OR duration_ms >= 0);

ALTER TABLE public.user_audit_logs 
ADD CONSTRAINT chk_risk_score_valid 
CHECK (risk_score >= 0 AND risk_score <= 100);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_session_id 
ON public.user_audit_logs (session_id);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_request_id 
ON public.user_audit_logs (request_id);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_api_endpoint 
ON public.user_audit_logs (api_endpoint);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_http_method 
ON public.user_audit_logs (http_method);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_response_status 
ON public.user_audit_logs (response_status);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_severity 
ON public.user_audit_logs (severity);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_category 
ON public.user_audit_logs (category);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_suspicious 
ON public.user_audit_logs (is_suspicious) 
WHERE is_suspicious = true;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_risk_score 
ON public.user_audit_logs (risk_score DESC) 
WHERE risk_score > 0;

-- Create GIN indexes for new JSONB columns and arrays
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_device_info 
ON public.user_audit_logs USING gin (device_info);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_location_info 
ON public.user_audit_logs USING gin (location_info);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_additional_data 
ON public.user_audit_logs USING gin (additional_data);

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_tags 
ON public.user_audit_logs USING gin (tags);

-- Add table and column comments
COMMENT ON TABLE public.user_audit_logs IS 'Comprehensive audit trail of all user actions and system interactions';
COMMENT ON COLUMN public.user_audit_logs.id IS 'Unique identifier for the audit log entry';
COMMENT ON COLUMN public.user_audit_logs.user_id IS 'User who performed the action';
COMMENT ON COLUMN public.user_audit_logs.target_user_id IS 'User who was the target of the action (if applicable)';
COMMENT ON COLUMN public.user_audit_logs.action IS 'Type of action performed';
COMMENT ON COLUMN public.user_audit_logs.table_name IS 'Database table affected (if applicable)';
COMMENT ON COLUMN public.user_audit_logs.record_id IS 'ID of the record affected (if applicable)';
COMMENT ON COLUMN public.user_audit_logs.old_values IS 'Previous values before the change';
COMMENT ON COLUMN public.user_audit_logs.new_values IS 'New values after the change';
COMMENT ON COLUMN public.user_audit_logs.ip_address IS 'IP address of the client';
COMMENT ON COLUMN public.user_audit_logs.user_agent IS 'User agent string from the client';
COMMENT ON COLUMN public.user_audit_logs.performed_by IS 'User who actually performed the action (for admin actions)';
COMMENT ON COLUMN public.user_audit_logs.session_id IS 'Session identifier';
COMMENT ON COLUMN public.user_audit_logs.request_id IS 'Request identifier for tracking';
COMMENT ON COLUMN public.user_audit_logs.api_endpoint IS 'API endpoint that was called';
COMMENT ON COLUMN public.user_audit_logs.http_method IS 'HTTP method used';
COMMENT ON COLUMN public.user_audit_logs.response_status IS 'HTTP response status code';
COMMENT ON COLUMN public.user_audit_logs.duration_ms IS 'Request duration in milliseconds';
COMMENT ON COLUMN public.user_audit_logs.error_message IS 'Error message if the action failed';
COMMENT ON COLUMN public.user_audit_logs.severity IS 'Severity level of the action';
COMMENT ON COLUMN public.user_audit_logs.category IS 'Category of the action';
COMMENT ON COLUMN public.user_audit_logs.device_info IS 'Device information as JSON';
COMMENT ON COLUMN public.user_audit_logs.location_info IS 'Location information as JSON';
COMMENT ON COLUMN public.user_audit_logs.additional_data IS 'Additional contextual data as JSON';
COMMENT ON COLUMN public.user_audit_logs.is_suspicious IS 'Whether the action is flagged as suspicious';
COMMENT ON COLUMN public.user_audit_logs.risk_score IS 'Risk score of the action (0-100)';
COMMENT ON COLUMN public.user_audit_logs.tags IS 'Tags for categorization and filtering';
COMMENT ON COLUMN public.user_audit_logs.created_at IS 'When the action was performed';

-- Create view for recent audit activities
CREATE OR REPLACE VIEW user_audit_logs_recent AS
SELECT 
    ual.id,
    ual.user_id,
    u.username,
    u.full_name as user_name,
    ual.target_user_id,
    tu.username as target_username,
    tu.full_name as target_user_name,
    ual.action,
    ual.table_name,
    ual.record_id,
    ual.old_values,
    ual.new_values,
    ual.ip_address,
    ual.user_agent,
    ual.performed_by,
    pb.username as performed_by_username,
    pb.full_name as performed_by_name,
    ual.session_id,
    ual.request_id,
    ual.api_endpoint,
    ual.http_method,
    ual.response_status,
    ual.duration_ms,
    ual.error_message,
    ual.severity,
    ual.category,
    ual.device_info,
    ual.location_info,
    ual.additional_data,
    ual.is_suspicious,
    ual.risk_score,
    ual.tags,
    ual.created_at
FROM user_audit_logs ual
LEFT JOIN users u ON ual.user_id = u.id
LEFT JOIN users tu ON ual.target_user_id = tu.id
LEFT JOIN users pb ON ual.performed_by = pb.id
WHERE ual.created_at >= now() - INTERVAL '30 days'
ORDER BY ual.created_at DESC;

-- Create function to log user action
CREATE OR REPLACE FUNCTION log_user_action(
    user_id_param UUID,
    action_param VARCHAR,
    table_name_param VARCHAR DEFAULT NULL,
    record_id_param UUID DEFAULT NULL,
    old_values_param JSONB DEFAULT NULL,
    new_values_param JSONB DEFAULT NULL,
    ip_address_param INET DEFAULT NULL,
    user_agent_param TEXT DEFAULT NULL,
    performed_by_param UUID DEFAULT NULL,
    session_id_param VARCHAR DEFAULT NULL,
    request_id_param VARCHAR DEFAULT NULL,
    api_endpoint_param VARCHAR DEFAULT NULL,
    http_method_param VARCHAR DEFAULT NULL,
    response_status_param INTEGER DEFAULT NULL,
    duration_ms_param INTEGER DEFAULT NULL,
    error_message_param TEXT DEFAULT NULL,
    severity_param VARCHAR DEFAULT 'info',
    category_param VARCHAR DEFAULT NULL,
    device_info_param JSONB DEFAULT '{}',
    location_info_param JSONB DEFAULT '{}',
    additional_data_param JSONB DEFAULT '{}',
    tags_param TEXT[] DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    log_id UUID;
    calculated_risk_score INTEGER := 0;
    is_suspicious_action BOOLEAN := false;
BEGIN
    -- Calculate risk score based on action type and context
    CASE action_param
        WHEN 'login_failed' THEN calculated_risk_score := 30;
        WHEN 'password_changed' THEN calculated_risk_score := 40;
        WHEN 'role_changed' THEN calculated_risk_score := 60;
        WHEN 'permission_granted', 'permission_revoked' THEN calculated_risk_score := 50;
        WHEN 'user_deleted' THEN calculated_risk_score := 80;
        WHEN 'admin_login' THEN calculated_risk_score := 70;
        ELSE calculated_risk_score := 10;
    END CASE;
    
    -- Check for suspicious patterns
    IF action_param IN ('login_failed', 'unauthorized_access', 'permission_denied') THEN
        is_suspicious_action := true;
        calculated_risk_score := calculated_risk_score + 20;
    END IF;
    
    -- Increase risk score for errors
    IF error_message_param IS NOT NULL THEN
        calculated_risk_score := calculated_risk_score + 15;
    END IF;
    
    -- Cap risk score at 100
    calculated_risk_score := LEAST(calculated_risk_score, 100);
    
    INSERT INTO user_audit_logs (
        user_id,
        action,
        table_name,
        record_id,
        old_values,
        new_values,
        ip_address,
        user_agent,
        performed_by,
        session_id,
        request_id,
        api_endpoint,
        http_method,
        response_status,
        duration_ms,
        error_message,
        severity,
        category,
        device_info,
        location_info,
        additional_data,
        is_suspicious,
        risk_score,
        tags
    ) VALUES (
        user_id_param,
        action_param,
        table_name_param,
        record_id_param,
        old_values_param,
        new_values_param,
        ip_address_param,
        user_agent_param,
        performed_by_param,
        session_id_param,
        request_id_param,
        api_endpoint_param,
        http_method_param,
        response_status_param,
        duration_ms_param,
        error_message_param,
        severity_param,
        category_param,
        device_info_param,
        location_info_param,
        additional_data_param,
        is_suspicious_action,
        calculated_risk_score,
        tags_param
    ) RETURNING id INTO log_id;
    
    RETURN log_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to get user activity summary
CREATE OR REPLACE FUNCTION get_user_activity_summary(
    user_id_param UUID,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_actions BIGINT,
    login_count BIGINT,
    failed_login_count BIGINT,
    data_changes BIGINT,
    suspicious_activities BIGINT,
    avg_risk_score DECIMAL,
    most_common_action VARCHAR,
    last_activity_at TIMESTAMPTZ,
    unique_ip_addresses BIGINT,
    total_duration_ms BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_actions,
        COUNT(*) FILTER (WHERE action = 'login') as login_count,
        COUNT(*) FILTER (WHERE action = 'login_failed') as failed_login_count,
        COUNT(*) FILTER (WHERE old_values IS NOT NULL OR new_values IS NOT NULL) as data_changes,
        COUNT(*) FILTER (WHERE is_suspicious = true) as suspicious_activities,
        AVG(risk_score) as avg_risk_score,
        (SELECT action FROM user_audit_logs WHERE user_id = user_id_param 
         AND (date_from IS NULL OR created_at >= date_from)
         AND (date_to IS NULL OR created_at <= date_to)
         GROUP BY action ORDER BY COUNT(*) DESC LIMIT 1) as most_common_action,
        MAX(created_at) as last_activity_at,
        COUNT(DISTINCT ip_address) as unique_ip_addresses,
        COALESCE(SUM(duration_ms), 0) as total_duration_ms
    FROM user_audit_logs
    WHERE user_id = user_id_param
      AND (date_from IS NULL OR created_at >= date_from)
      AND (date_to IS NULL OR created_at <= date_to);
END;
$$ LANGUAGE plpgsql;

-- Create function to get suspicious activities
CREATE OR REPLACE FUNCTION get_suspicious_activities(
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL,
    min_risk_score INTEGER DEFAULT 50,
    limit_param INTEGER DEFAULT 100
)
RETURNS TABLE(
    log_id UUID,
    user_id UUID,
    username VARCHAR,
    action VARCHAR,
    ip_address INET,
    risk_score INTEGER,
    error_message TEXT,
    created_at TIMESTAMPTZ,
    additional_context JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ual.id,
        ual.user_id,
        u.username,
        ual.action,
        ual.ip_address,
        ual.risk_score,
        ual.error_message,
        ual.created_at,
        jsonb_build_object(
            'user_agent', ual.user_agent,
            'api_endpoint', ual.api_endpoint,
            'response_status', ual.response_status,
            'device_info', ual.device_info,
            'location_info', ual.location_info
        ) as additional_context
    FROM user_audit_logs ual
    LEFT JOIN users u ON ual.user_id = u.id
    WHERE (ual.is_suspicious = true OR ual.risk_score >= min_risk_score)
      AND (date_from IS NULL OR ual.created_at >= date_from)
      AND (date_to IS NULL OR ual.created_at <= date_to)
    ORDER BY ual.risk_score DESC, ual.created_at DESC
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql;

-- Create function to get audit trail for a specific record
CREATE OR REPLACE FUNCTION get_record_audit_trail(
    table_name_param VARCHAR,
    record_id_param UUID
)
RETURNS TABLE(
    log_id UUID,
    user_id UUID,
    username VARCHAR,
    action VARCHAR,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ual.id,
        ual.user_id,
        u.username,
        ual.action,
        ual.old_values,
        ual.new_values,
        ual.ip_address,
        ual.created_at
    FROM user_audit_logs ual
    LEFT JOIN users u ON ual.user_id = u.id
    WHERE ual.table_name = table_name_param 
      AND ual.record_id = record_id_param
    ORDER BY ual.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to cleanup old audit logs
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs(
    retention_days INTEGER DEFAULT 365
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM user_audit_logs 
    WHERE created_at < now() - (retention_days || ' days')::INTERVAL
      AND severity NOT IN ('error', 'critical')
      AND is_suspicious = false;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get audit statistics
CREATE OR REPLACE FUNCTION get_audit_statistics(
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_logs BIGINT,
    unique_users BIGINT,
    unique_ip_addresses BIGINT,
    total_errors BIGINT,
    suspicious_activities BIGINT,
    avg_risk_score DECIMAL,
    most_active_user VARCHAR,
    most_common_action VARCHAR,
    peak_activity_hour INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_logs,
        COUNT(DISTINCT user_id) as unique_users,
        COUNT(DISTINCT ip_address) as unique_ip_addresses,
        COUNT(*) FILTER (WHERE error_message IS NOT NULL) as total_errors,
        COUNT(*) FILTER (WHERE is_suspicious = true) as suspicious_activities,
        AVG(risk_score) as avg_risk_score,
        (SELECT u.username FROM user_audit_logs ual
         JOIN users u ON ual.user_id = u.id
         WHERE (date_from IS NULL OR ual.created_at >= date_from)
         AND (date_to IS NULL OR ual.created_at <= date_to)
         GROUP BY u.username ORDER BY COUNT(*) DESC LIMIT 1) as most_active_user,
        (SELECT action FROM user_audit_logs
         WHERE (date_from IS NULL OR created_at >= date_from)
         AND (date_to IS NULL OR created_at <= date_to)
         GROUP BY action ORDER BY COUNT(*) DESC LIMIT 1) as most_common_action,
        (SELECT EXTRACT(HOUR FROM created_at)::INTEGER FROM user_audit_logs
         WHERE (date_from IS NULL OR created_at >= date_from)
         AND (date_to IS NULL OR created_at <= date_to)
         GROUP BY EXTRACT(HOUR FROM created_at) ORDER BY COUNT(*) DESC LIMIT 1) as peak_activity_hour
    FROM user_audit_logs
    WHERE (date_from IS NULL OR created_at >= date_from)
      AND (date_to IS NULL OR created_at <= date_to);
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'user_audit_logs table created with comprehensive auditing and security monitoring features';