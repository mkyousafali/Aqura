-- =====================================================
-- Table: user_password_history
-- Description: User password history tracking for security and compliance
-- This table maintains historical password records to enforce password reuse policies
-- =====================================================

-- Create user_password_history table
CREATE TABLE public.user_password_history (
    -- Primary key with UUID generation using extensions
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    
    -- Foreign key to users table
    user_id UUID NOT NULL,
    
    -- Password security data
    password_hash CHARACTER VARYING(255) NOT NULL,
    salt CHARACTER VARYING(100) NOT NULL,
    
    -- Audit timestamp
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    -- Primary key constraint
    CONSTRAINT user_password_history_pkey PRIMARY KEY (id),
    
    -- Foreign key to users table with CASCADE delete
    CONSTRAINT user_password_history_user_id_fkey 
        FOREIGN KEY (user_id) 
        REFERENCES users (id) 
        ON DELETE CASCADE,
    
    -- Check constraints for data integrity
    CONSTRAINT chk_password_hash_not_empty 
        CHECK (length(trim(password_hash)) > 0),
    
    CONSTRAINT chk_salt_not_empty 
        CHECK (length(trim(salt)) > 0),
    
    -- Check constraint for reasonable hash length (bcrypt, scrypt, argon2)
    CONSTRAINT chk_password_hash_length 
        CHECK (length(password_hash) >= 32 AND length(password_hash) <= 255),
    
    -- Check constraint for reasonable salt length
    CONSTRAINT chk_salt_length 
        CHECK (length(salt) >= 8 AND length(salt) <= 100)
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Primary composite index for user password timeline queries
CREATE INDEX IF NOT EXISTS idx_password_history_user_created 
    ON public.user_password_history 
    USING btree (user_id, created_at DESC) 
    TABLESPACE pg_default;

-- Individual user lookup index
CREATE INDEX IF NOT EXISTS idx_password_history_user_id 
    ON public.user_password_history 
    USING btree (user_id) 
    TABLESPACE pg_default;

-- Temporal index for cleanup and maintenance
CREATE INDEX IF NOT EXISTS idx_password_history_created_at 
    ON public.user_password_history 
    USING btree (created_at DESC) 
    TABLESPACE pg_default;

-- Hash lookup index for password reuse checking (partial for performance)
CREATE INDEX IF NOT EXISTS idx_password_history_hash_lookup 
    ON public.user_password_history 
    USING btree (user_id, password_hash) 
    TABLESPACE pg_default;

-- Recent passwords index for quick policy enforcement
CREATE INDEX IF NOT EXISTS idx_password_history_recent 
    ON public.user_password_history 
    USING btree (user_id, created_at DESC) 
    TABLESPACE pg_default
    WHERE created_at >= now() - INTERVAL '2 years';

-- =====================================================
-- Functions for Password History Management
-- =====================================================

-- Function to add password to history
CREATE OR REPLACE FUNCTION add_password_to_history(
    p_user_id UUID,
    p_password_hash VARCHAR(255),
    p_salt VARCHAR(100)
)
RETURNS UUID AS $$
DECLARE
    history_id UUID;
BEGIN
    -- Insert new password history record
    INSERT INTO public.user_password_history (
        user_id, password_hash, salt
    ) VALUES (
        p_user_id, p_password_hash, p_salt
    )
    RETURNING id INTO history_id;
    
    RETURN history_id;
END;
$$ LANGUAGE plpgsql;

-- Function to check password reuse (security policy enforcement)
CREATE OR REPLACE FUNCTION check_password_reuse(
    p_user_id UUID,
    p_password_hash VARCHAR(255),
    p_history_limit INTEGER DEFAULT 12
)
RETURNS BOOLEAN AS $$
DECLARE
    reuse_found BOOLEAN := false;
BEGIN
    -- Check if password hash exists in recent history
    SELECT EXISTS(
        SELECT 1 
        FROM public.user_password_history 
        WHERE user_id = p_user_id 
          AND password_hash = p_password_hash
        ORDER BY created_at DESC
        LIMIT p_history_limit
    ) INTO reuse_found;
    
    RETURN reuse_found;
END;
$$ LANGUAGE plpgsql;

-- Function to get user password history
CREATE OR REPLACE FUNCTION get_user_password_history(
    p_user_id UUID,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    history_id UUID,
    password_hash VARCHAR,
    salt VARCHAR,
    created_at TIMESTAMP WITH TIME ZONE,
    age_days INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uph.id as history_id,
        uph.password_hash,
        uph.salt,
        uph.created_at,
        EXTRACT(DAYS FROM (now() - uph.created_at))::INTEGER as age_days
    FROM public.user_password_history uph
    WHERE uph.user_id = p_user_id
    ORDER BY uph.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup old password history
CREATE OR REPLACE FUNCTION cleanup_password_history(
    p_retention_months INTEGER DEFAULT 24,
    p_min_records_to_keep INTEGER DEFAULT 5
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
    user_record RECORD;
    records_to_delete INTEGER;
BEGIN
    -- Process each user individually to maintain minimum records
    FOR user_record IN 
        SELECT DISTINCT user_id 
        FROM public.user_password_history
    LOOP
        -- Calculate how many records to delete for this user
        SELECT COUNT(*) - p_min_records_to_keep INTO records_to_delete
        FROM public.user_password_history
        WHERE user_id = user_record.user_id
          AND created_at < now() - (p_retention_months || ' months')::INTERVAL;
        
        -- Only delete if we have more than minimum records
        IF records_to_delete > 0 THEN
            DELETE FROM public.user_password_history
            WHERE id IN (
                SELECT id
                FROM public.user_password_history
                WHERE user_id = user_record.user_id
                  AND created_at < now() - (p_retention_months || ' months')::INTERVAL
                ORDER BY created_at ASC
                LIMIT records_to_delete
            );
            
            GET DIAGNOSTICS records_to_delete = ROW_COUNT;
            deleted_count := deleted_count + records_to_delete;
        END IF;
    END LOOP;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get password age statistics
CREATE OR REPLACE FUNCTION get_password_age_statistics(
    p_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    user_id UUID,
    current_password_age_days INTEGER,
    password_change_frequency_days NUMERIC,
    total_password_changes INTEGER,
    first_password_date TIMESTAMP WITH TIME ZONE,
    last_password_change TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uph.user_id,
        EXTRACT(DAYS FROM (now() - MAX(uph.created_at)))::INTEGER as current_password_age_days,
        CASE 
            WHEN COUNT(*) > 1 THEN 
                EXTRACT(DAYS FROM (MAX(uph.created_at) - MIN(uph.created_at))) / (COUNT(*) - 1)
            ELSE NULL 
        END as password_change_frequency_days,
        COUNT(*)::INTEGER as total_password_changes,
        MIN(uph.created_at) as first_password_date,
        MAX(uph.created_at) as last_password_change
    FROM public.user_password_history uph
    WHERE (p_user_id IS NULL OR uph.user_id = p_user_id)
    GROUP BY uph.user_id
    ORDER BY current_password_age_days DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to validate password policy compliance
CREATE OR REPLACE FUNCTION validate_password_policy(
    p_user_id UUID,
    p_new_password_hash VARCHAR(255),
    p_policy_history_limit INTEGER DEFAULT 12,
    p_policy_min_age_days INTEGER DEFAULT 1
)
RETURNS TABLE (
    is_compliant BOOLEAN,
    violation_reason TEXT,
    days_since_last_change INTEGER
) AS $$
DECLARE
    reuse_found BOOLEAN;
    days_since_last INTEGER;
    last_change_date TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Check password reuse
    SELECT check_password_reuse(p_user_id, p_new_password_hash, p_policy_history_limit) 
    INTO reuse_found;
    
    -- Get last password change date
    SELECT MAX(created_at) INTO last_change_date
    FROM public.user_password_history
    WHERE user_id = p_user_id;
    
    -- Calculate days since last change
    IF last_change_date IS NOT NULL THEN
        days_since_last := EXTRACT(DAYS FROM (now() - last_change_date))::INTEGER;
    ELSE
        days_since_last := NULL;
    END IF;
    
    -- Return compliance status
    RETURN QUERY
    SELECT 
        CASE 
            WHEN reuse_found THEN false
            WHEN days_since_last IS NOT NULL AND days_since_last < p_policy_min_age_days THEN false
            ELSE true
        END as is_compliant,
        CASE 
            WHEN reuse_found THEN 'Password has been used recently and cannot be reused'
            WHEN days_since_last IS NOT NULL AND days_since_last < p_policy_min_age_days THEN 
                'Password was changed too recently. Minimum age is ' || p_policy_min_age_days || ' days'
            ELSE 'Password meets policy requirements'
        END as violation_reason,
        COALESCE(days_since_last, 0) as days_since_last_change;
END;
$$ LANGUAGE plpgsql;

-- Function to find users with old passwords
CREATE OR REPLACE FUNCTION find_users_with_old_passwords(
    p_max_age_days INTEGER DEFAULT 90
)
RETURNS TABLE (
    user_id UUID,
    user_email VARCHAR,
    password_age_days INTEGER,
    last_password_change TIMESTAMP WITH TIME ZONE,
    total_password_changes INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        latest.user_id,
        u.email as user_email,
        EXTRACT(DAYS FROM (now() - latest.last_change))::INTEGER as password_age_days,
        latest.last_change as last_password_change,
        COUNT(uph.id)::INTEGER as total_password_changes
    FROM (
        SELECT 
            uph.user_id,
            MAX(uph.created_at) as last_change
        FROM public.user_password_history uph
        GROUP BY uph.user_id
        HAVING MAX(uph.created_at) < now() - (p_max_age_days || ' days')::INTERVAL
    ) latest
    JOIN public.users u ON latest.user_id = u.id
    JOIN public.user_password_history uph ON latest.user_id = uph.user_id
    GROUP BY latest.user_id, u.email, latest.last_change
    ORDER BY password_age_days DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Triggers for Automatic Maintenance
-- =====================================================

-- Create trigger function for automatic cleanup
CREATE OR REPLACE FUNCTION trigger_password_history_maintenance()
RETURNS TRIGGER AS $$
DECLARE
    user_history_count INTEGER;
    max_history_limit INTEGER := 50; -- Configurable limit
BEGIN
    -- Count current history records for this user
    SELECT COUNT(*) INTO user_history_count
    FROM public.user_password_history
    WHERE user_id = NEW.user_id;
    
    -- If we exceed the limit, remove oldest records
    IF user_history_count > max_history_limit THEN
        DELETE FROM public.user_password_history
        WHERE id IN (
            SELECT id
            FROM public.user_password_history
            WHERE user_id = NEW.user_id
            ORDER BY created_at ASC
            LIMIT (user_history_count - max_history_limit)
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic maintenance
CREATE TRIGGER trigger_password_history_auto_cleanup
    AFTER INSERT ON public.user_password_history
    FOR EACH ROW
    EXECUTE FUNCTION trigger_password_history_maintenance();

-- =====================================================
-- Views for Password Security Analysis
-- =====================================================

-- View for password security overview
CREATE OR REPLACE VIEW password_security_overview AS
SELECT 
    u.id as user_id,
    u.email,
    latest_password.created_at as last_password_change,
    EXTRACT(DAYS FROM (now() - latest_password.created_at))::INTEGER as password_age_days,
    history_stats.total_changes,
    history_stats.avg_change_frequency_days,
    CASE 
        WHEN EXTRACT(DAYS FROM (now() - latest_password.created_at)) > 90 THEN 'OLD'
        WHEN EXTRACT(DAYS FROM (now() - latest_password.created_at)) > 60 THEN 'AGING'
        WHEN EXTRACT(DAYS FROM (now() - latest_password.created_at)) > 30 THEN 'RECENT'
        ELSE 'NEW'
    END as password_status
FROM public.users u
LEFT JOIN (
    SELECT 
        user_id,
        MAX(created_at) as created_at
    FROM public.user_password_history
    GROUP BY user_id
) latest_password ON u.id = latest_password.user_id
LEFT JOIN (
    SELECT 
        user_id,
        COUNT(*) as total_changes,
        CASE 
            WHEN COUNT(*) > 1 THEN 
                EXTRACT(DAYS FROM (MAX(created_at) - MIN(created_at))) / (COUNT(*) - 1)
            ELSE NULL 
        END as avg_change_frequency_days
    FROM public.user_password_history
    GROUP BY user_id
) history_stats ON u.id = history_stats.user_id
ORDER BY password_age_days DESC NULLS LAST;

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.user_password_history IS 'User password history tracking for security and compliance - maintains historical password records to enforce password reuse policies';

COMMENT ON COLUMN public.user_password_history.id IS 'Primary key - unique identifier for each password history record';
COMMENT ON COLUMN public.user_password_history.user_id IS 'Foreign key to users table - which user this password belongs to';
COMMENT ON COLUMN public.user_password_history.password_hash IS 'Cryptographic hash of the password (bcrypt, scrypt, argon2, etc.)';
COMMENT ON COLUMN public.user_password_history.salt IS 'Cryptographic salt used with the password hash';
COMMENT ON COLUMN public.user_password_history.created_at IS 'Timestamp when this password was set';

-- Index comments
COMMENT ON INDEX idx_password_history_user_created IS 'Primary composite index for user password timeline queries and policy enforcement';
COMMENT ON INDEX idx_password_history_hash_lookup IS 'Performance index for password reuse checking during policy validation';
COMMENT ON INDEX idx_password_history_recent IS 'Partial index for recent passwords to optimize policy enforcement queries';

-- Function comments
COMMENT ON FUNCTION add_password_to_history(UUID, VARCHAR, VARCHAR) IS 'Adds a new password to user history for policy tracking';
COMMENT ON FUNCTION check_password_reuse(UUID, VARCHAR, INTEGER) IS 'Checks if a password has been used recently to enforce reuse policies';
COMMENT ON FUNCTION get_user_password_history(UUID, INTEGER) IS 'Returns chronological password history for a user';
COMMENT ON FUNCTION validate_password_policy(UUID, VARCHAR, INTEGER, INTEGER) IS 'Comprehensive password policy validation including reuse and age requirements';
COMMENT ON FUNCTION find_users_with_old_passwords(INTEGER) IS 'Identifies users whose passwords exceed maximum age policies';
COMMENT ON FUNCTION cleanup_password_history(INTEGER, INTEGER) IS 'Data retention function with configurable retention period and minimum record preservation';

-- View comments
COMMENT ON VIEW password_security_overview IS 'Comprehensive password security analysis view for administrative monitoring and compliance reporting';