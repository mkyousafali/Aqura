-- Create user_password_history table for tracking password changes and enforcing password policies
-- This table stores historical passwords to prevent password reuse

-- Create the user_password_history table
CREATE TABLE IF NOT EXISTS public.user_password_history (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    user_id UUID NOT NULL,
    password_hash CHARACTER VARYING(255) NOT NULL,
    salt CHARACTER VARYING(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT user_password_history_pkey PRIMARY KEY (id),
    CONSTRAINT user_password_history_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for efficient queries (original index)
CREATE INDEX IF NOT EXISTS idx_password_history_user_created 
ON public.user_password_history USING btree (user_id, created_at DESC) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_password_history_user_id 
ON public.user_password_history (user_id);

CREATE INDEX IF NOT EXISTS idx_password_history_created_at 
ON public.user_password_history (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_password_history_password_hash 
ON public.user_password_history (password_hash);

-- Add additional validation constraints
ALTER TABLE public.user_password_history 
ADD CONSTRAINT chk_password_hash_not_empty 
CHECK (TRIM(password_hash) != '');

ALTER TABLE public.user_password_history 
ADD CONSTRAINT chk_salt_not_empty 
CHECK (TRIM(salt) != '');

-- Add additional columns for enhanced functionality
ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS hash_algorithm VARCHAR(50) DEFAULT 'bcrypt';

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS hash_iterations INTEGER;

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS password_strength_score INTEGER;

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS changed_by UUID;

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS change_reason VARCHAR(100);

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS ip_address INET;

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS user_agent TEXT;

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS is_admin_reset BOOLEAN DEFAULT false;

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS is_force_change BOOLEAN DEFAULT false;

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS password_metadata JSONB DEFAULT '{}';

ALTER TABLE public.user_password_history 
ADD COLUMN IF NOT EXISTS compliance_flags JSONB DEFAULT '{}';

-- Add foreign key for changed_by
ALTER TABLE public.user_password_history 
ADD CONSTRAINT user_password_history_changed_by_fkey 
FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE SET NULL;

-- Add validation for new columns
ALTER TABLE public.user_password_history 
ADD CONSTRAINT chk_hash_algorithm_valid 
CHECK (hash_algorithm IN ('bcrypt', 'scrypt', 'argon2', 'pbkdf2', 'sha256', 'md5'));

ALTER TABLE public.user_password_history 
ADD CONSTRAINT chk_hash_iterations_positive 
CHECK (hash_iterations IS NULL OR hash_iterations > 0);

ALTER TABLE public.user_password_history 
ADD CONSTRAINT chk_password_strength_valid 
CHECK (password_strength_score IS NULL OR (password_strength_score >= 0 AND password_strength_score <= 100));

ALTER TABLE public.user_password_history 
ADD CONSTRAINT chk_change_reason_valid 
CHECK (change_reason IS NULL OR change_reason IN (
    'user_initiated', 'admin_reset', 'forced_change', 'security_breach', 'policy_compliance', 
    'account_recovery', 'first_login', 'scheduled_change', 'expired_password'
));

ALTER TABLE public.user_password_history 
ADD CONSTRAINT chk_expires_at_after_created 
CHECK (expires_at IS NULL OR expires_at > created_at);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_password_history_hash_algorithm 
ON public.user_password_history (hash_algorithm);

CREATE INDEX IF NOT EXISTS idx_password_history_changed_by 
ON public.user_password_history (changed_by);

CREATE INDEX IF NOT EXISTS idx_password_history_change_reason 
ON public.user_password_history (change_reason);

CREATE INDEX IF NOT EXISTS idx_password_history_ip_address 
ON public.user_password_history (ip_address);

CREATE INDEX IF NOT EXISTS idx_password_history_admin_reset 
ON public.user_password_history (is_admin_reset) 
WHERE is_admin_reset = true;

CREATE INDEX IF NOT EXISTS idx_password_history_force_change 
ON public.user_password_history (is_force_change) 
WHERE is_force_change = true;

CREATE INDEX IF NOT EXISTS idx_password_history_expires_at 
ON public.user_password_history (expires_at) 
WHERE expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_password_history_strength_score 
ON public.user_password_history (password_strength_score DESC) 
WHERE password_strength_score IS NOT NULL;

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_password_history_metadata 
ON public.user_password_history USING gin (password_metadata);

CREATE INDEX IF NOT EXISTS idx_password_history_compliance_flags 
ON public.user_password_history USING gin (compliance_flags);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_password_history_user_reason 
ON public.user_password_history (user_id, change_reason);

CREATE INDEX IF NOT EXISTS idx_password_history_user_admin_reset 
ON public.user_password_history (user_id, is_admin_reset, created_at DESC);

-- Add table and column comments
COMMENT ON TABLE public.user_password_history IS 'Password history tracking for security compliance and policy enforcement';
COMMENT ON COLUMN public.user_password_history.id IS 'Unique identifier for the password history record';
COMMENT ON COLUMN public.user_password_history.user_id IS 'Reference to the user';
COMMENT ON COLUMN public.user_password_history.password_hash IS 'Hashed password value';
COMMENT ON COLUMN public.user_password_history.salt IS 'Salt used for password hashing';
COMMENT ON COLUMN public.user_password_history.hash_algorithm IS 'Algorithm used for password hashing';
COMMENT ON COLUMN public.user_password_history.hash_iterations IS 'Number of iterations used in hashing';
COMMENT ON COLUMN public.user_password_history.password_strength_score IS 'Password strength score (0-100)';
COMMENT ON COLUMN public.user_password_history.changed_by IS 'User who initiated the password change';
COMMENT ON COLUMN public.user_password_history.change_reason IS 'Reason for the password change';
COMMENT ON COLUMN public.user_password_history.ip_address IS 'IP address where change was initiated';
COMMENT ON COLUMN public.user_password_history.user_agent IS 'User agent of the client';
COMMENT ON COLUMN public.user_password_history.is_admin_reset IS 'Whether this was an admin-initiated reset';
COMMENT ON COLUMN public.user_password_history.is_force_change IS 'Whether this was a forced password change';
COMMENT ON COLUMN public.user_password_history.expires_at IS 'When this password expires (if applicable)';
COMMENT ON COLUMN public.user_password_history.password_metadata IS 'Additional password metadata';
COMMENT ON COLUMN public.user_password_history.compliance_flags IS 'Compliance and policy flags';
COMMENT ON COLUMN public.user_password_history.created_at IS 'When the password was set';

-- Create view for password history with user details
CREATE OR REPLACE VIEW user_password_history_detailed AS
SELECT 
    uph.id,
    uph.user_id,
    u.username,
    u.full_name as user_name,
    uph.password_hash,
    uph.salt,
    uph.hash_algorithm,
    uph.hash_iterations,
    uph.password_strength_score,
    uph.changed_by,
    cb.username as changed_by_username,
    cb.full_name as changed_by_name,
    uph.change_reason,
    uph.ip_address,
    uph.user_agent,
    uph.is_admin_reset,
    uph.is_force_change,
    uph.expires_at,
    uph.password_metadata,
    uph.compliance_flags,
    uph.created_at,
    CASE 
        WHEN uph.expires_at IS NOT NULL AND uph.expires_at < now() THEN true
        ELSE false
    END as is_expired,
    EXTRACT(EPOCH FROM (now() - uph.created_at)) / 86400 as days_since_created
FROM user_password_history uph
LEFT JOIN users u ON uph.user_id = u.id
LEFT JOIN users cb ON uph.changed_by = cb.id
ORDER BY uph.created_at DESC;

-- Create function to add password to history
CREATE OR REPLACE FUNCTION add_password_to_history(
    user_id_param UUID,
    password_hash_param VARCHAR,
    salt_param VARCHAR,
    hash_algorithm_param VARCHAR DEFAULT 'bcrypt',
    hash_iterations_param INTEGER DEFAULT NULL,
    password_strength_score_param INTEGER DEFAULT NULL,
    changed_by_param UUID DEFAULT NULL,
    change_reason_param VARCHAR DEFAULT 'user_initiated',
    ip_address_param INET DEFAULT NULL,
    user_agent_param TEXT DEFAULT NULL,
    is_admin_reset_param BOOLEAN DEFAULT false,
    is_force_change_param BOOLEAN DEFAULT false,
    expires_at_param TIMESTAMPTZ DEFAULT NULL,
    metadata_param JSONB DEFAULT '{}',
    compliance_flags_param JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    history_id UUID;
BEGIN
    INSERT INTO user_password_history (
        user_id,
        password_hash,
        salt,
        hash_algorithm,
        hash_iterations,
        password_strength_score,
        changed_by,
        change_reason,
        ip_address,
        user_agent,
        is_admin_reset,
        is_force_change,
        expires_at,
        password_metadata,
        compliance_flags
    ) VALUES (
        user_id_param,
        password_hash_param,
        salt_param,
        hash_algorithm_param,
        hash_iterations_param,
        password_strength_score_param,
        changed_by_param,
        change_reason_param,
        ip_address_param,
        user_agent_param,
        is_admin_reset_param,
        is_force_change_param,
        expires_at_param,
        metadata_param,
        compliance_flags_param
    ) RETURNING id INTO history_id;
    
    RETURN history_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to check password reuse
CREATE OR REPLACE FUNCTION check_password_reuse(
    user_id_param UUID,
    password_hash_param VARCHAR,
    history_limit INTEGER DEFAULT 12
)
RETURNS BOOLEAN AS $$
DECLARE
    is_reused BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 
        FROM user_password_history 
        WHERE user_id = user_id_param 
          AND password_hash = password_hash_param
        ORDER BY created_at DESC 
        LIMIT history_limit
    ) INTO is_reused;
    
    RETURN is_reused;
END;
$$ LANGUAGE plpgsql;

-- Create function to get user password statistics
CREATE OR REPLACE FUNCTION get_user_password_statistics(
    user_id_param UUID,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_password_changes BIGINT,
    admin_resets BIGINT,
    user_initiated_changes BIGINT,
    forced_changes BIGINT,
    avg_password_strength DECIMAL,
    last_password_change TIMESTAMPTZ,
    password_change_frequency_days DECIMAL,
    unique_ip_addresses BIGINT,
    most_common_change_reason VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_password_changes,
        COUNT(*) FILTER (WHERE is_admin_reset = true) as admin_resets,
        COUNT(*) FILTER (WHERE change_reason = 'user_initiated') as user_initiated_changes,
        COUNT(*) FILTER (WHERE is_force_change = true) as forced_changes,
        AVG(password_strength_score) FILTER (WHERE password_strength_score IS NOT NULL) as avg_password_strength,
        MAX(created_at) as last_password_change,
        CASE 
            WHEN COUNT(*) > 1 THEN 
                EXTRACT(EPOCH FROM (MAX(created_at) - MIN(created_at))) / 86400 / (COUNT(*) - 1)
            ELSE NULL
        END as password_change_frequency_days,
        COUNT(DISTINCT ip_address) as unique_ip_addresses,
        (SELECT change_reason FROM user_password_history 
         WHERE user_id = user_id_param 
         AND change_reason IS NOT NULL
         AND (date_from IS NULL OR created_at >= date_from)
         AND (date_to IS NULL OR created_at <= date_to)
         GROUP BY change_reason ORDER BY COUNT(*) DESC LIMIT 1) as most_common_change_reason
    FROM user_password_history
    WHERE user_id = user_id_param
      AND (date_from IS NULL OR created_at >= date_from)
      AND (date_to IS NULL OR created_at <= date_to);
END;
$$ LANGUAGE plpgsql;

-- Create function to get recent password changes
CREATE OR REPLACE FUNCTION get_recent_password_changes(
    hours_back INTEGER DEFAULT 24,
    limit_param INTEGER DEFAULT 50
)
RETURNS TABLE(
    history_id UUID,
    user_id UUID,
    username VARCHAR,
    change_reason VARCHAR,
    is_admin_reset BOOLEAN,
    password_strength_score INTEGER,
    ip_address INET,
    changed_by UUID,
    changed_by_username VARCHAR,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uph.id,
        uph.user_id,
        u.username,
        uph.change_reason,
        uph.is_admin_reset,
        uph.password_strength_score,
        uph.ip_address,
        uph.changed_by,
        cb.username as changed_by_username,
        uph.created_at
    FROM user_password_history uph
    LEFT JOIN users u ON uph.user_id = u.id
    LEFT JOIN users cb ON uph.changed_by = cb.id
    WHERE uph.created_at >= now() - (hours_back || ' hours')::INTERVAL
    ORDER BY uph.created_at DESC
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql;

-- Create function to enforce password history policy
CREATE OR REPLACE FUNCTION enforce_password_history_policy(
    user_id_param UUID,
    new_password_hash VARCHAR,
    policy_history_limit INTEGER DEFAULT 12,
    policy_min_age_days INTEGER DEFAULT 1
)
RETURNS TABLE(
    is_valid BOOLEAN,
    violation_reasons TEXT[]
) AS $$
DECLARE
    reasons TEXT[] := '{}';
    last_change_date TIMESTAMPTZ;
    is_reused BOOLEAN;
BEGIN
    -- Check if password is being reused
    SELECT check_password_reuse(user_id_param, new_password_hash, policy_history_limit) INTO is_reused;
    
    IF is_reused THEN
        reasons := reasons || 'password_recently_used';
    END IF;
    
    -- Check minimum password age
    SELECT created_at INTO last_change_date 
    FROM user_password_history 
    WHERE user_id = user_id_param 
    ORDER BY created_at DESC 
    LIMIT 1;
    
    IF last_change_date IS NOT NULL AND 
       last_change_date > now() - (policy_min_age_days || ' days')::INTERVAL THEN
        reasons := reasons || 'password_changed_too_recently';
    END IF;
    
    RETURN QUERY SELECT 
        (array_length(reasons, 1) IS NULL) as is_valid,
        reasons as violation_reasons;
END;
$$ LANGUAGE plpgsql;

-- Create function to cleanup old password history
CREATE OR REPLACE FUNCTION cleanup_old_password_history(
    retention_limit INTEGER DEFAULT 24,
    retention_days INTEGER DEFAULT 1095
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Delete old password history beyond retention limit and days
    WITH user_password_ranks AS (
        SELECT 
            id,
            user_id,
            created_at,
            ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) as rank
        FROM user_password_history
    )
    DELETE FROM user_password_history
    WHERE id IN (
        SELECT upr.id
        FROM user_password_ranks upr
        WHERE upr.rank > retention_limit
           OR upr.created_at < now() - (retention_days || ' days')::INTERVAL
    );
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get password compliance report
CREATE OR REPLACE FUNCTION get_password_compliance_report(
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_users_changed_passwords BIGINT,
    admin_resets_count BIGINT,
    forced_changes_count BIGINT,
    avg_password_strength DECIMAL,
    weak_passwords_count BIGINT,
    users_with_expired_passwords BIGINT,
    compliance_score DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT user_id) as total_users_changed_passwords,
        COUNT(*) FILTER (WHERE is_admin_reset = true) as admin_resets_count,
        COUNT(*) FILTER (WHERE is_force_change = true) as forced_changes_count,
        AVG(password_strength_score) FILTER (WHERE password_strength_score IS NOT NULL) as avg_password_strength,
        COUNT(*) FILTER (WHERE password_strength_score IS NOT NULL AND password_strength_score < 60) as weak_passwords_count,
        COUNT(*) FILTER (WHERE expires_at IS NOT NULL AND expires_at < now()) as users_with_expired_passwords,
        CASE 
            WHEN COUNT(*) > 0 THEN
                (COUNT(*) FILTER (WHERE password_strength_score IS NULL OR password_strength_score >= 60)::DECIMAL / COUNT(*)) * 100
            ELSE 0
        END as compliance_score
    FROM user_password_history
    WHERE (date_from IS NULL OR created_at >= date_from)
      AND (date_to IS NULL OR created_at <= date_to);
END;
$$ LANGUAGE plpgsql;

-- Create function to get users with weak passwords
CREATE OR REPLACE FUNCTION get_users_with_weak_passwords(
    strength_threshold INTEGER DEFAULT 60
)
RETURNS TABLE(
    user_id UUID,
    username VARCHAR,
    current_password_strength INTEGER,
    password_age_days INTEGER,
    last_changed_at TIMESTAMPTZ,
    change_reason VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH latest_passwords AS (
        SELECT DISTINCT ON (uph.user_id)
            uph.user_id,
            uph.password_strength_score,
            uph.created_at,
            uph.change_reason
        FROM user_password_history uph
        ORDER BY uph.user_id, uph.created_at DESC
    )
    SELECT 
        lp.user_id,
        u.username,
        lp.password_strength_score as current_password_strength,
        EXTRACT(EPOCH FROM (now() - lp.created_at)) / 86400 as password_age_days,
        lp.created_at as last_changed_at,
        lp.change_reason
    FROM latest_passwords lp
    LEFT JOIN users u ON lp.user_id = u.id
    WHERE lp.password_strength_score IS NOT NULL 
      AND lp.password_strength_score < strength_threshold
    ORDER BY lp.password_strength_score ASC, lp.created_at ASC;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'user_password_history table created with comprehensive password tracking and policy enforcement features';