-- Create users table for comprehensive user management with authentication and authorization
-- This table serves as the core user entity with extensive security and profile features

-- Create the users table
CREATE TABLE IF NOT EXISTS public.users (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    username CHARACTER VARYING(50) NOT NULL,
    password_hash CHARACTER VARYING(255) NOT NULL,
    salt CHARACTER VARYING(100) NOT NULL,
    quick_access_code CHARACTER VARYING(6) NOT NULL,
    quick_access_salt CHARACTER VARYING(100) NOT NULL,
    user_type public.user_type_enum NOT NULL DEFAULT 'branch_specific'::user_type_enum,
    employee_id UUID NULL,
    branch_id BIGINT NULL,
    role_type public.role_type_enum NULL DEFAULT 'Position-based'::role_type_enum,
    position_id UUID NULL,
    avatar TEXT NULL,
    avatar_small_url TEXT NULL,
    avatar_medium_url TEXT NULL,
    avatar_large_url TEXT NULL,
    is_first_login BOOLEAN NULL DEFAULT true,
    failed_login_attempts INTEGER NULL DEFAULT 0,
    locked_at TIMESTAMP WITH TIME ZONE NULL,
    locked_by UUID NULL,
    last_login_at TIMESTAMP WITH TIME ZONE NULL,
    password_expires_at TIMESTAMP WITH TIME ZONE NULL,
    last_password_change TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    created_by BIGINT NULL,
    updated_by BIGINT NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    status CHARACTER VARYING(20) NOT NULL DEFAULT 'active'::character varying,
    ai_translation_enabled BOOLEAN NOT NULL DEFAULT false,
    
    CONSTRAINT users_pkey PRIMARY KEY (id),
    CONSTRAINT users_username_key UNIQUE (username),
    CONSTRAINT users_quick_access_code_key UNIQUE (quick_access_code),
    CONSTRAINT users_locked_by_fkey FOREIGN KEY (locked_by) REFERENCES users (id),
    CONSTRAINT users_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE SET NULL,
    CONSTRAINT users_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id) ON DELETE SET NULL,
    CONSTRAINT users_employee_branch_check CHECK (
        (user_type = 'global'::user_type_enum)
        OR (
            (user_type = 'branch_specific'::user_type_enum)
            AND (branch_id IS NOT NULL)
        )
    ),
    CONSTRAINT users_quick_access_length CHECK (length((quick_access_code)::text) = 6),
    CONSTRAINT users_quick_access_numeric CHECK (((quick_access_code)::text ~ '^[0-9]{6}$'::text))
) TABLESPACE pg_default;

-- Create original indexes
CREATE INDEX IF NOT EXISTS idx_users_username 
ON public.users USING btree (username) 
TABLESPACE pg_default;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_quick_access 
ON public.users USING btree (quick_access_code) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_role_type 
ON public.users USING btree (role_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_employee_id 
ON public.users USING btree (employee_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_branch_id 
ON public.users USING btree (branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_created_at 
ON public.users USING btree (created_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_last_login 
ON public.users USING btree (last_login_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_employee_lookup 
ON public.users USING btree (employee_id) 
TABLESPACE pg_default
WHERE (employee_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_users_branch_lookup 
ON public.users USING btree (branch_id) 
TABLESPACE pg_default
WHERE (branch_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_users_position_lookup 
ON public.users USING btree (position_id) 
TABLESPACE pg_default
WHERE (position_id IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_users_ai_translation_enabled 
ON public.users USING btree (ai_translation_enabled) 
TABLESPACE pg_default;

-- Add additional columns for enhanced functionality
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS full_name VARCHAR(255);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS display_name VARCHAR(100);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS email VARCHAR(320);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN DEFAULT false;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS birth_date DATE;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS gender VARCHAR(20);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS timezone VARCHAR(50) DEFAULT 'UTC';

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS language_preference VARCHAR(10) DEFAULT 'en';

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS theme_preference VARCHAR(20) DEFAULT 'system';

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS notification_preferences JSONB DEFAULT '{}';

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS privacy_settings JSONB DEFAULT '{}';

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS security_settings JSONB DEFAULT '{}';

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS profile_metadata JSONB DEFAULT '{}';

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN DEFAULT false;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS two_factor_secret VARCHAR(32);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS backup_codes TEXT[];

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS password_strength_score INTEGER;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS security_questions JSONB DEFAULT '{}';

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS account_verification_token VARCHAR(255);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS email_verification_token VARCHAR(255);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS phone_verification_token VARCHAR(6);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS password_reset_token VARCHAR(255);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS password_reset_expires_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS login_streak INTEGER DEFAULT 0;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS max_login_streak INTEGER DEFAULT 0;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS total_login_count INTEGER DEFAULT 0;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS last_ip_address INET;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS last_user_agent TEXT;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS device_fingerprint VARCHAR(255);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS trusted_devices JSONB DEFAULT '[]';

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS session_timeout_minutes INTEGER DEFAULT 480;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS force_password_change BOOLEAN DEFAULT false;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS account_locked_reason VARCHAR(100);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS unlock_token VARCHAR(255);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS unlock_expires_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS deactivated_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS deactivated_by UUID;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS deleted_by UUID;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS terms_version VARCHAR(10);

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS gdpr_consent BOOLEAN DEFAULT false;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS gdpr_consent_date TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS marketing_consent BOOLEAN DEFAULT false;

ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS data_retention_date TIMESTAMP WITH TIME ZONE;

-- Add foreign key constraints for new columns
ALTER TABLE public.users 
ADD CONSTRAINT users_deactivated_by_fkey 
FOREIGN KEY (deactivated_by) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE public.users 
ADD CONSTRAINT users_deleted_by_fkey 
FOREIGN KEY (deleted_by) REFERENCES users (id) ON DELETE SET NULL;

-- Add validation constraints
ALTER TABLE public.users 
ADD CONSTRAINT chk_username_format 
CHECK (username ~ '^[a-zA-Z0-9_.-]+$');

ALTER TABLE public.users 
ADD CONSTRAINT chk_username_length 
CHECK (length(username) >= 3);

ALTER TABLE public.users 
ADD CONSTRAINT chk_email_format 
CHECK (email IS NULL OR email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

ALTER TABLE public.users 
ADD CONSTRAINT chk_phone_format 
CHECK (phone_number IS NULL OR phone_number ~ '^\+?[1-9]\d{6,14}$');

ALTER TABLE public.users 
ADD CONSTRAINT chk_password_strength_valid 
CHECK (password_strength_score IS NULL OR (password_strength_score >= 0 AND password_strength_score <= 100));

ALTER TABLE public.users 
ADD CONSTRAINT chk_failed_attempts_positive 
CHECK (failed_login_attempts >= 0);

ALTER TABLE public.users 
ADD CONSTRAINT chk_login_streak_positive 
CHECK (login_streak >= 0 AND max_login_streak >= 0);

ALTER TABLE public.users 
ADD CONSTRAINT chk_total_login_positive 
CHECK (total_login_count >= 0);

ALTER TABLE public.users 
ADD CONSTRAINT chk_session_timeout_valid 
CHECK (session_timeout_minutes > 0 AND session_timeout_minutes <= 10080);

ALTER TABLE public.users 
ADD CONSTRAINT chk_status_valid 
CHECK (status IN ('active', 'inactive', 'suspended', 'locked', 'pending', 'deactivated', 'deleted'));

ALTER TABLE public.users 
ADD CONSTRAINT chk_gender_valid 
CHECK (gender IS NULL OR gender IN ('male', 'female', 'other', 'prefer_not_to_say'));

ALTER TABLE public.users 
ADD CONSTRAINT chk_theme_valid 
CHECK (theme_preference IN ('light', 'dark', 'system', 'high_contrast'));

ALTER TABLE public.users 
ADD CONSTRAINT chk_birth_date_realistic 
CHECK (birth_date IS NULL OR (birth_date >= '1900-01-01' AND birth_date <= CURRENT_DATE));

ALTER TABLE public.users 
ADD CONSTRAINT chk_phone_verification_token_format 
CHECK (phone_verification_token IS NULL OR phone_verification_token ~ '^[0-9]{6}$');

ALTER TABLE public.users 
ADD CONSTRAINT chk_password_reset_token_future 
CHECK (password_reset_expires_at IS NULL OR password_reset_expires_at > now());

-- Create additional indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_users_email 
ON public.users (email) 
WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_phone 
ON public.users (phone_number) 
WHERE phone_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_full_name 
ON public.users (full_name) 
WHERE full_name IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_status 
ON public.users (status);

CREATE INDEX IF NOT EXISTS idx_users_locked_at 
ON public.users (locked_at) 
WHERE locked_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_failed_attempts 
ON public.users (failed_login_attempts) 
WHERE failed_login_attempts > 0;

CREATE INDEX IF NOT EXISTS idx_users_password_expires 
ON public.users (password_expires_at) 
WHERE password_expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_two_factor 
ON public.users (two_factor_enabled) 
WHERE two_factor_enabled = true;

CREATE INDEX IF NOT EXISTS idx_users_email_verified 
ON public.users (email_verified, email) 
WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_phone_verified 
ON public.users (phone_verified, phone_number) 
WHERE phone_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_language 
ON public.users (language_preference);

CREATE INDEX IF NOT EXISTS idx_users_timezone 
ON public.users (timezone);

CREATE INDEX IF NOT EXISTS idx_users_deactivated 
ON public.users (deactivated_at, deactivated_by) 
WHERE deactivated_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_deleted 
ON public.users (deleted_at, deleted_by) 
WHERE deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_device_fingerprint 
ON public.users (device_fingerprint) 
WHERE device_fingerprint IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_password_reset 
ON public.users (password_reset_token, password_reset_expires_at) 
WHERE password_reset_token IS NOT NULL;

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_users_notification_preferences 
ON public.users USING gin (notification_preferences);

CREATE INDEX IF NOT EXISTS idx_users_privacy_settings 
ON public.users USING gin (privacy_settings);

CREATE INDEX IF NOT EXISTS idx_users_security_settings 
ON public.users USING gin (security_settings);

CREATE INDEX IF NOT EXISTS idx_users_profile_metadata 
ON public.users USING gin (profile_metadata);

CREATE INDEX IF NOT EXISTS idx_users_security_questions 
ON public.users USING gin (security_questions);

CREATE INDEX IF NOT EXISTS idx_users_trusted_devices 
ON public.users USING gin (trusted_devices);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_users_branch_status 
ON public.users (branch_id, status);

CREATE INDEX IF NOT EXISTS idx_users_employee_status 
ON public.users (employee_id, status);

CREATE INDEX IF NOT EXISTS idx_users_type_status 
ON public.users (user_type, status);

CREATE INDEX IF NOT EXISTS idx_users_active_lookup 
ON public.users (status, username) 
WHERE status = 'active';

-- Add table and column comments
COMMENT ON TABLE public.users IS 'Core user management table with comprehensive authentication, authorization, and profile features';
COMMENT ON COLUMN public.users.id IS 'Unique identifier for the user';
COMMENT ON COLUMN public.users.username IS 'Unique username for login';
COMMENT ON COLUMN public.users.password_hash IS 'Hashed password for authentication';
COMMENT ON COLUMN public.users.salt IS 'Salt used for password hashing';
COMMENT ON COLUMN public.users.quick_access_code IS 'Six-digit numeric code for quick access';
COMMENT ON COLUMN public.users.quick_access_salt IS 'Salt for quick access code hashing';
COMMENT ON COLUMN public.users.user_type IS 'Type of user (global or branch-specific)';
COMMENT ON COLUMN public.users.employee_id IS 'Reference to HR employee record';
COMMENT ON COLUMN public.users.branch_id IS 'Branch assignment for branch-specific users';
COMMENT ON COLUMN public.users.role_type IS 'Type of role assignment';
COMMENT ON COLUMN public.users.position_id IS 'Position assignment reference';
COMMENT ON COLUMN public.users.full_name IS 'Complete name of the user';
COMMENT ON COLUMN public.users.display_name IS 'Preferred display name';
COMMENT ON COLUMN public.users.email IS 'Email address for communication';
COMMENT ON COLUMN public.users.email_verified IS 'Whether email has been verified';
COMMENT ON COLUMN public.users.phone_number IS 'Phone number for contact and verification';
COMMENT ON COLUMN public.users.phone_verified IS 'Whether phone number has been verified';
COMMENT ON COLUMN public.users.birth_date IS 'Date of birth';
COMMENT ON COLUMN public.users.gender IS 'Gender identification';
COMMENT ON COLUMN public.users.timezone IS 'User timezone preference';
COMMENT ON COLUMN public.users.language_preference IS 'Preferred language code';
COMMENT ON COLUMN public.users.theme_preference IS 'UI theme preference';
COMMENT ON COLUMN public.users.notification_preferences IS 'Notification settings and preferences';
COMMENT ON COLUMN public.users.privacy_settings IS 'Privacy configuration options';
COMMENT ON COLUMN public.users.security_settings IS 'Security configuration and options';
COMMENT ON COLUMN public.users.profile_metadata IS 'Additional profile information';
COMMENT ON COLUMN public.users.two_factor_enabled IS 'Whether two-factor authentication is enabled';
COMMENT ON COLUMN public.users.two_factor_secret IS 'TOTP secret for two-factor authentication';
COMMENT ON COLUMN public.users.backup_codes IS 'Backup codes for account recovery';
COMMENT ON COLUMN public.users.password_strength_score IS 'Password strength score (0-100)';
COMMENT ON COLUMN public.users.security_questions IS 'Security questions and hashed answers';
COMMENT ON COLUMN public.users.failed_login_attempts IS 'Number of consecutive failed login attempts';
COMMENT ON COLUMN public.users.locked_at IS 'When the account was locked';
COMMENT ON COLUMN public.users.locked_by IS 'User who locked this account';
COMMENT ON COLUMN public.users.account_locked_reason IS 'Reason for account lock';
COMMENT ON COLUMN public.users.login_streak IS 'Current consecutive login streak';
COMMENT ON COLUMN public.users.max_login_streak IS 'Maximum login streak achieved';
COMMENT ON COLUMN public.users.total_login_count IS 'Total number of successful logins';
COMMENT ON COLUMN public.users.trusted_devices IS 'List of trusted device identifiers';
COMMENT ON COLUMN public.users.force_password_change IS 'Whether user must change password on next login';
COMMENT ON COLUMN public.users.terms_accepted_at IS 'When terms of service were accepted';
COMMENT ON COLUMN public.users.gdpr_consent IS 'GDPR consent status';
COMMENT ON COLUMN public.users.marketing_consent IS 'Marketing communication consent';

-- Create view for active users with profile information
CREATE OR REPLACE VIEW active_users_profile AS
SELECT 
    u.id,
    u.username,
    u.full_name,
    u.display_name,
    u.email,
    u.email_verified,
    u.phone_number,
    u.phone_verified,
    u.user_type,
    u.branch_id,
    b.name as branch_name,
    u.employee_id,
    u.position_id,
    u.role_type,
    u.avatar,
    u.status,
    u.is_first_login,
    u.last_login_at,
    u.created_at,
    u.timezone,
    u.language_preference,
    u.theme_preference,
    u.two_factor_enabled,
    u.ai_translation_enabled,
    CASE 
        WHEN u.locked_at IS NOT NULL THEN true
        ELSE false
    END as is_locked,
    CASE 
        WHEN u.password_expires_at IS NOT NULL AND u.password_expires_at < now() THEN true
        ELSE false
    END as password_expired,
    EXTRACT(EPOCH FROM (now() - u.last_login_at)) / 86400 as days_since_last_login
FROM users u
LEFT JOIN branches b ON u.branch_id = b.id
WHERE u.status = 'active' 
  AND u.deleted_at IS NULL
ORDER BY u.last_login_at DESC NULLS LAST;

-- Create original triggers
CREATE TRIGGER update_users_updated_at 
BEFORE UPDATE ON users 
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER users_audit_trigger 
AFTER INSERT OR DELETE OR UPDATE ON users 
FOR EACH ROW 
EXECUTE FUNCTION log_user_action();

-- Create function to create a new user
CREATE OR REPLACE FUNCTION create_user(
    username_param VARCHAR,
    password_hash_param VARCHAR,
    salt_param VARCHAR,
    quick_access_code_param VARCHAR,
    quick_access_salt_param VARCHAR,
    user_type_param user_type_enum DEFAULT 'branch_specific',
    branch_id_param BIGINT DEFAULT NULL,
    employee_id_param UUID DEFAULT NULL,
    full_name_param VARCHAR DEFAULT NULL,
    email_param VARCHAR DEFAULT NULL,
    phone_param VARCHAR DEFAULT NULL,
    created_by_param BIGINT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    user_id UUID;
BEGIN
    -- Validate branch requirement for branch-specific users
    IF user_type_param = 'branch_specific' AND branch_id_param IS NULL THEN
        RAISE EXCEPTION 'Branch ID is required for branch-specific users';
    END IF;
    
    INSERT INTO users (
        username,
        password_hash,
        salt,
        quick_access_code,
        quick_access_salt,
        user_type,
        branch_id,
        employee_id,
        full_name,
        email,
        phone_number,
        created_by
    ) VALUES (
        username_param,
        password_hash_param,
        salt_param,
        quick_access_code_param,
        quick_access_salt_param,
        user_type_param,
        branch_id_param,
        employee_id_param,
        full_name_param,
        email_param,
        phone_param,
        created_by_param
    ) RETURNING id INTO user_id;
    
    RETURN user_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update login tracking
CREATE OR REPLACE FUNCTION update_user_login_tracking(
    user_id_param UUID,
    ip_address_param INET DEFAULT NULL,
    user_agent_param TEXT DEFAULT NULL,
    device_fingerprint_param VARCHAR DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    current_streak INTEGER;
    max_streak INTEGER;
    last_login DATE;
    today DATE := CURRENT_DATE;
BEGIN
    -- Get current values
    SELECT login_streak, max_login_streak, last_login_at::DATE 
    INTO current_streak, max_streak, last_login
    FROM users 
    WHERE id = user_id_param;
    
    -- Calculate new streak
    IF last_login IS NULL OR last_login = today THEN
        -- First login or same day login
        current_streak := COALESCE(current_streak, 0) + 1;
    ELSIF last_login = today - INTERVAL '1 day' THEN
        -- Consecutive day
        current_streak := current_streak + 1;
    ELSE
        -- Streak broken
        current_streak := 1;
    END IF;
    
    -- Update max streak if needed
    IF current_streak > COALESCE(max_streak, 0) THEN
        max_streak := current_streak;
    END IF;
    
    -- Update user record
    UPDATE users 
    SET 
        last_login_at = now(),
        login_streak = current_streak,
        max_login_streak = max_streak,
        total_login_count = COALESCE(total_login_count, 0) + 1,
        failed_login_attempts = 0,
        last_ip_address = ip_address_param,
        last_user_agent = user_agent_param,
        device_fingerprint = device_fingerprint_param,
        is_first_login = false
    WHERE id = user_id_param;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Create function to handle failed login attempts
CREATE OR REPLACE FUNCTION handle_failed_login(
    username_param VARCHAR,
    ip_address_param INET DEFAULT NULL,
    max_attempts INTEGER DEFAULT 5,
    lockout_duration_minutes INTEGER DEFAULT 30
)
RETURNS TABLE(
    user_id UUID,
    is_locked BOOLEAN,
    attempts_remaining INTEGER,
    lockout_expires_at TIMESTAMPTZ
) AS $$
DECLARE
    user_record RECORD;
    new_attempts INTEGER;
    should_lock BOOLEAN := false;
    unlock_time TIMESTAMPTZ;
BEGIN
    -- Get user record
    SELECT id, failed_login_attempts, locked_at INTO user_record
    FROM users 
    WHERE username = username_param;
    
    IF user_record.id IS NULL THEN
        RAISE EXCEPTION 'User not found';
    END IF;
    
    -- Increment failed attempts
    new_attempts := COALESCE(user_record.failed_login_attempts, 0) + 1;
    
    -- Check if should lock
    IF new_attempts >= max_attempts AND user_record.locked_at IS NULL THEN
        should_lock := true;
        unlock_time := now() + (lockout_duration_minutes || ' minutes')::INTERVAL;
    END IF;
    
    -- Update user record
    UPDATE users 
    SET 
        failed_login_attempts = new_attempts,
        locked_at = CASE WHEN should_lock THEN now() ELSE locked_at END,
        account_locked_reason = CASE WHEN should_lock THEN 'max_failed_attempts' ELSE account_locked_reason END,
        unlock_expires_at = CASE WHEN should_lock THEN unlock_time ELSE unlock_expires_at END,
        last_ip_address = ip_address_param
    WHERE id = user_record.id;
    
    RETURN QUERY SELECT 
        user_record.id,
        should_lock OR user_record.locked_at IS NOT NULL,
        GREATEST(0, max_attempts - new_attempts),
        CASE WHEN should_lock THEN unlock_time ELSE user_record.locked_at + (lockout_duration_minutes || ' minutes')::INTERVAL END;
END;
$$ LANGUAGE plpgsql;

-- Create function to unlock user account
CREATE OR REPLACE FUNCTION unlock_user_account(
    user_id_param UUID,
    unlocked_by_param UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    user_exists BOOLEAN;
BEGIN
    UPDATE users 
    SET 
        locked_at = NULL,
        failed_login_attempts = 0,
        account_locked_reason = NULL,
        unlock_token = NULL,
        unlock_expires_at = NULL,
        updated_by = unlocked_by_param,
        updated_at = now()
    WHERE id = user_id_param 
      AND locked_at IS NOT NULL;
    
    GET DIAGNOSTICS user_exists = FOUND;
    RETURN user_exists;
END;
$$ LANGUAGE plpgsql;

-- Create function to get user statistics
CREATE OR REPLACE FUNCTION get_user_statistics(
    branch_id_param BIGINT DEFAULT NULL,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_users BIGINT,
    active_users BIGINT,
    locked_users BIGINT,
    new_users_period BIGINT,
    users_with_2fa BIGINT,
    avg_login_streak DECIMAL,
    users_by_type JSONB,
    users_by_status JSONB,
    email_verified_users BIGINT,
    phone_verified_users BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_users,
        COUNT(*) FILTER (WHERE status = 'active' AND deleted_at IS NULL) as active_users,
        COUNT(*) FILTER (WHERE locked_at IS NOT NULL) as locked_users,
        COUNT(*) FILTER (WHERE 
            (date_from IS NULL OR created_at >= date_from) AND 
            (date_to IS NULL OR created_at <= date_to)
        ) as new_users_period,
        COUNT(*) FILTER (WHERE two_factor_enabled = true) as users_with_2fa,
        AVG(login_streak) as avg_login_streak,
        jsonb_object_agg(user_type, type_count) as users_by_type,
        jsonb_object_agg(status, status_count) as users_by_status,
        COUNT(*) FILTER (WHERE email_verified = true) as email_verified_users,
        COUNT(*) FILTER (WHERE phone_verified = true) as phone_verified_users
    FROM users u
    LEFT JOIN (
        SELECT user_type, COUNT(*) as type_count
        FROM users
        WHERE (branch_id_param IS NULL OR branch_id = branch_id_param)
          AND deleted_at IS NULL
        GROUP BY user_type
    ) type_stats ON true
    LEFT JOIN (
        SELECT status, COUNT(*) as status_count
        FROM users
        WHERE (branch_id_param IS NULL OR branch_id = branch_id_param)
          AND deleted_at IS NULL
        GROUP BY status
    ) status_stats ON true
    WHERE (branch_id_param IS NULL OR u.branch_id = branch_id_param)
      AND u.deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'users table created with comprehensive user management, authentication, and profile features';