-- =====================================================
-- Table: users
-- Description: Core user management system with authentication and authorization
-- This table manages all user accounts with comprehensive security and audit features
-- =====================================================

-- Create enum types for user management (if not exists)
DO $$ BEGIN
    CREATE TYPE user_type_enum AS ENUM (
        'global',
        'branch_specific'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE role_type_enum AS ENUM (
        'Position-based',
        'Custom-role'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE user_status_enum AS ENUM (
        'active',
        'inactive',
        'suspended',
        'locked',
        'pending_activation',
        'archived'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create users table
CREATE TABLE public.users (
    -- Primary key with UUID generation using extensions
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    
    -- Authentication credentials
    username CHARACTER VARYING(50) NOT NULL,
    password_hash CHARACTER VARYING(255) NOT NULL,
    salt CHARACTER VARYING(100) NOT NULL,
    quick_access_code CHARACTER VARYING(6) NOT NULL,
    quick_access_salt CHARACTER VARYING(100) NOT NULL,
    
    -- User classification and relationships
    user_type public.user_type_enum NOT NULL DEFAULT 'branch_specific'::user_type_enum,
    employee_id UUID NULL,
    branch_id BIGINT NULL,
    role_type public.role_type_enum NULL DEFAULT 'Position-based'::role_type_enum,
    position_id UUID NULL,
    
    -- Profile and avatar management
    full_name CHARACTER VARYING(200) NULL,
    email CHARACTER VARYING(255) NULL,
    phone CHARACTER VARYING(20) NULL,
    avatar TEXT NULL,
    avatar_small_url TEXT NULL,
    avatar_medium_url TEXT NULL,
    avatar_large_url TEXT NULL,
    
    -- Account status and security
    status public.user_status_enum NULL DEFAULT 'active'::user_status_enum,
    is_first_login BOOLEAN NULL DEFAULT true,
    failed_login_attempts INTEGER NULL DEFAULT 0,
    locked_at TIMESTAMP WITH TIME ZONE NULL,
    locked_by UUID NULL,
    last_login_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Password management
    password_expires_at TIMESTAMP WITH TIME ZONE NULL,
    last_password_change TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    password_reset_token VARCHAR(255) NULL,
    password_reset_expires_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Two-factor authentication
    two_factor_enabled BOOLEAN NULL DEFAULT false,
    two_factor_secret VARCHAR(255) NULL,
    backup_codes TEXT[] NULL,
    
    -- Account preferences
    language_preference VARCHAR(5) NULL DEFAULT 'en',
    timezone VARCHAR(50) NULL DEFAULT 'UTC',
    theme_preference VARCHAR(20) NULL DEFAULT 'light',
    notification_preferences JSONB NULL DEFAULT '{"email": true, "push": true, "sms": false}'::jsonb,
    
    -- Audit fields
    created_by BIGINT NULL,
    updated_by BIGINT NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    -- Primary key constraint
    CONSTRAINT users_pkey PRIMARY KEY (id),
    
    -- Unique constraints
    CONSTRAINT users_username_key UNIQUE (username),
    CONSTRAINT users_quick_access_code_key UNIQUE (quick_access_code),
    CONSTRAINT users_email_key UNIQUE (email),
    
    -- Foreign key constraints
    CONSTRAINT users_locked_by_fkey 
        FOREIGN KEY (locked_by) 
        REFERENCES users (id)
        ON DELETE SET NULL,
    
    CONSTRAINT users_branch_id_fkey 
        FOREIGN KEY (branch_id) 
        REFERENCES branches (id) 
        ON DELETE SET NULL,
    
    CONSTRAINT users_employee_id_fkey 
        FOREIGN KEY (employee_id) 
        REFERENCES hr_employees (id) 
        ON DELETE SET NULL,
    
    CONSTRAINT users_position_id_fkey 
        FOREIGN KEY (position_id) 
        REFERENCES hr_positions (id) 
        ON DELETE SET NULL,
    
    -- Business logic constraints
    CONSTRAINT users_employee_branch_check 
        CHECK (
            (user_type = 'global'::user_type_enum)
            OR (
                (user_type = 'branch_specific'::user_type_enum)
                AND (branch_id IS NOT NULL)
            )
        ),
    
    -- Quick access code validation
    CONSTRAINT users_quick_access_length 
        CHECK (length(quick_access_code::text) = 6),
    
    CONSTRAINT users_quick_access_numeric 
        CHECK (quick_access_code::text ~ '^[0-9]{6}$'::text),
    
    -- Additional validation constraints
    CONSTRAINT chk_username_format 
        CHECK (username ~ '^[a-zA-Z0-9._-]+$' AND length(username) >= 3),
    
    CONSTRAINT chk_email_format 
        CHECK (email IS NULL OR email ~ '^[^@]+@[^@]+\.[^@]+$'),
    
    CONSTRAINT chk_phone_format 
        CHECK (phone IS NULL OR phone ~ '^\+?[0-9\s\-\(\)]+$'),
    
    CONSTRAINT chk_password_hash_not_empty 
        CHECK (length(trim(password_hash)) > 0),
    
    CONSTRAINT chk_salt_not_empty 
        CHECK (length(trim(salt)) > 0),
    
    CONSTRAINT chk_failed_attempts_range 
        CHECK (failed_login_attempts >= 0 AND failed_login_attempts <= 10),
    
    CONSTRAINT chk_language_preference_valid 
        CHECK (language_preference IN ('en', 'ar', 'fr', 'es', 'de')),
    
    CONSTRAINT chk_theme_preference_valid 
        CHECK (theme_preference IN ('light', 'dark', 'auto')),
    
    -- Password expiry logic
    CONSTRAINT chk_password_expiry_future 
        CHECK (password_expires_at IS NULL OR password_expires_at > last_password_change),
    
    -- Lock consistency
    CONSTRAINT chk_locked_consistency 
        CHECK (
            (status != 'locked' AND locked_at IS NULL AND locked_by IS NULL)
            OR 
            (status = 'locked' AND locked_at IS NOT NULL)
        ),
    
    -- Two-factor authentication consistency
    CONSTRAINT chk_two_factor_consistency 
        CHECK (
            (two_factor_enabled = false AND two_factor_secret IS NULL)
            OR 
            (two_factor_enabled = true AND two_factor_secret IS NOT NULL)
        )
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Authentication indexes
CREATE INDEX IF NOT EXISTS idx_users_username 
    ON public.users 
    USING btree (username) 
    TABLESPACE pg_default;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_quick_access 
    ON public.users 
    USING btree (quick_access_code) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_email 
    ON public.users 
    USING btree (email) 
    TABLESPACE pg_default
    WHERE email IS NOT NULL;

-- Status and security indexes
CREATE INDEX IF NOT EXISTS idx_users_status 
    ON public.users 
    USING btree (status) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_role_type 
    ON public.users 
    USING btree (role_type) 
    TABLESPACE pg_default;

-- Relationship indexes
CREATE INDEX IF NOT EXISTS idx_users_employee_id 
    ON public.users 
    USING btree (employee_id) 
    TABLESPACE pg_default
    WHERE employee_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_branch_id 
    ON public.users 
    USING btree (branch_id) 
    TABLESPACE pg_default
    WHERE branch_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_position_id 
    ON public.users 
    USING btree (position_id) 
    TABLESPACE pg_default
    WHERE position_id IS NOT NULL;

-- Temporal indexes
CREATE INDEX IF NOT EXISTS idx_users_created_at 
    ON public.users 
    USING btree (created_at) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_last_login 
    ON public.users 
    USING btree (last_login_at) 
    TABLESPACE pg_default
    WHERE last_login_at IS NOT NULL;

-- Security monitoring indexes
CREATE INDEX IF NOT EXISTS idx_users_failed_attempts 
    ON public.users 
    USING btree (failed_login_attempts) 
    TABLESPACE pg_default
    WHERE failed_login_attempts > 0;

CREATE INDEX IF NOT EXISTS idx_users_locked 
    ON public.users 
    USING btree (locked_at, locked_by) 
    TABLESPACE pg_default
    WHERE locked_at IS NOT NULL;

-- Password management indexes
CREATE INDEX IF NOT EXISTS idx_users_password_expiry 
    ON public.users 
    USING btree (password_expires_at) 
    TABLESPACE pg_default
    WHERE password_expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_users_password_reset 
    ON public.users 
    USING btree (password_reset_token, password_reset_expires_at) 
    TABLESPACE pg_default
    WHERE password_reset_token IS NOT NULL;

-- Full-text search index
CREATE INDEX IF NOT EXISTS idx_users_search 
    ON public.users 
    USING gin (to_tsvector('english', 
        COALESCE(full_name, '') || ' ' || 
        COALESCE(username, '') || ' ' || 
        COALESCE(email, '')
    )) 
    TABLESPACE pg_default;

-- Composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_users_branch_status 
    ON public.users 
    USING btree (branch_id, status) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_type_status 
    ON public.users 
    USING btree (user_type, status) 
    TABLESPACE pg_default;

-- =====================================================
-- Trigger Functions
-- =====================================================

-- Create or replace the update_updated_at_column function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create or replace the log_user_action function
CREATE OR REPLACE FUNCTION log_user_action()
RETURNS TRIGGER AS $$
DECLARE
    action_type VARCHAR(10);
    old_values JSONB;
    new_values JSONB;
BEGIN
    -- Determine action type
    IF TG_OP = 'INSERT' THEN
        action_type := 'INSERT';
        old_values := NULL;
        new_values := to_jsonb(NEW);
    ELSIF TG_OP = 'UPDATE' THEN
        action_type := 'UPDATE';
        old_values := to_jsonb(OLD);
        new_values := to_jsonb(NEW);
    ELSIF TG_OP = 'DELETE' THEN
        action_type := 'DELETE';
        old_values := to_jsonb(OLD);
        new_values := NULL;
    END IF;
    
    -- Log the action (assumes user_audit_logs table exists)
    INSERT INTO public.user_audit_logs (
        user_id, 
        action_type, 
        table_name, 
        old_values, 
        new_values,
        ip_address,
        user_agent
    ) VALUES (
        COALESCE(NEW.id, OLD.id),
        action_type,
        'users',
        old_values,
        new_values,
        inet_client_addr(),
        NULL -- Can be populated from application context
    );
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER users_audit_trigger
    AFTER INSERT OR DELETE OR UPDATE ON users 
    FOR EACH ROW
    EXECUTE FUNCTION log_user_action();

-- =====================================================
-- Functions for User Management
-- =====================================================

-- Function to create a new user
CREATE OR REPLACE FUNCTION create_user(
    p_username VARCHAR(50),
    p_password_hash VARCHAR(255),
    p_salt VARCHAR(100),
    p_quick_access_code VARCHAR(6),
    p_quick_access_salt VARCHAR(100),
    p_user_type user_type_enum DEFAULT 'branch_specific',
    p_branch_id BIGINT DEFAULT NULL,
    p_employee_id UUID DEFAULT NULL,
    p_full_name VARCHAR(200) DEFAULT NULL,
    p_email VARCHAR(255) DEFAULT NULL,
    p_created_by BIGINT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    user_id UUID;
BEGIN
    -- Validate business rules
    IF p_user_type = 'branch_specific' AND p_branch_id IS NULL THEN
        RAISE EXCEPTION 'Branch-specific users must have a branch_id';
    END IF;
    
    -- Insert new user
    INSERT INTO public.users (
        username, password_hash, salt, quick_access_code, quick_access_salt,
        user_type, branch_id, employee_id, full_name, email, created_by
    ) VALUES (
        p_username, p_password_hash, p_salt, p_quick_access_code, p_quick_access_salt,
        p_user_type, p_branch_id, p_employee_id, p_full_name, p_email, p_created_by
    )
    RETURNING id INTO user_id;
    
    RETURN user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to authenticate user
CREATE OR REPLACE FUNCTION authenticate_user(
    p_username VARCHAR(50),
    p_password_hash VARCHAR(255)
)
RETURNS TABLE (
    user_id UUID,
    username VARCHAR,
    full_name VARCHAR,
    email VARCHAR,
    user_type user_type_enum,
    status user_status_enum,
    branch_id BIGINT,
    employee_id UUID,
    position_id UUID,
    is_first_login BOOLEAN,
    last_login_at TIMESTAMP WITH TIME ZONE,
    failed_attempts INTEGER,
    is_locked BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as user_id,
        u.username,
        u.full_name,
        u.email,
        u.user_type,
        u.status,
        u.branch_id,
        u.employee_id,
        u.position_id,
        u.is_first_login,
        u.last_login_at,
        u.failed_login_attempts as failed_attempts,
        (u.status = 'locked')::BOOLEAN as is_locked
    FROM public.users u
    WHERE u.username = p_username 
      AND u.password_hash = p_password_hash
      AND u.status IN ('active', 'pending_activation');
END;
$$ LANGUAGE plpgsql;

-- Function to update login tracking
CREATE OR REPLACE FUNCTION update_login_tracking(
    p_user_id UUID,
    p_success BOOLEAN,
    p_ip_address INET DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_success THEN
        -- Successful login
        UPDATE public.users
        SET 
            last_login_at = now(),
            failed_login_attempts = 0,
            is_first_login = false
        WHERE id = p_user_id;
        
        -- Log successful login (assumes user_sessions table)
        -- This would typically create a session record
        
    ELSE
        -- Failed login
        UPDATE public.users
        SET 
            failed_login_attempts = failed_login_attempts + 1,
            locked_at = CASE 
                WHEN failed_login_attempts + 1 >= 5 THEN now()
                ELSE locked_at
            END,
            status = CASE 
                WHEN failed_login_attempts + 1 >= 5 THEN 'locked'::user_status_enum
                ELSE status
            END
        WHERE id = p_user_id;
    END IF;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to reset password
CREATE OR REPLACE FUNCTION initiate_password_reset(
    p_username VARCHAR(50),
    p_reset_token VARCHAR(255),
    p_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    default_expiry TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Set default expiry if not provided (1 hour)
    IF p_expires_at IS NULL THEN
        default_expiry := now() + INTERVAL '1 hour';
    ELSE
        default_expiry := p_expires_at;
    END IF;
    
    -- Update user with reset token
    UPDATE public.users
    SET 
        password_reset_token = p_reset_token,
        password_reset_expires_at = default_expiry
    WHERE username = p_username
      AND status IN ('active', 'locked');
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to complete password reset
CREATE OR REPLACE FUNCTION complete_password_reset(
    p_reset_token VARCHAR(255),
    p_new_password_hash VARCHAR(255),
    p_new_salt VARCHAR(100)
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Update password and clear reset token
    UPDATE public.users
    SET 
        password_hash = p_new_password_hash,
        salt = p_new_salt,
        password_reset_token = NULL,
        password_reset_expires_at = NULL,
        last_password_change = now(),
        failed_login_attempts = 0,
        status = CASE 
            WHEN status = 'locked' THEN 'active'::user_status_enum
            ELSE status
        END,
        locked_at = NULL,
        locked_by = NULL
    WHERE password_reset_token = p_reset_token
      AND password_reset_expires_at > now();
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to lock/unlock user
CREATE OR REPLACE FUNCTION update_user_lock_status(
    p_user_id UUID,
    p_lock BOOLEAN,
    p_locked_by UUID DEFAULT NULL,
    p_reason VARCHAR(255) DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_lock THEN
        -- Lock user
        UPDATE public.users
        SET 
            status = 'locked'::user_status_enum,
            locked_at = now(),
            locked_by = p_locked_by
        WHERE id = p_user_id
          AND status != 'locked';
    ELSE
        -- Unlock user
        UPDATE public.users
        SET 
            status = 'active'::user_status_enum,
            locked_at = NULL,
            locked_by = NULL,
            failed_login_attempts = 0
        WHERE id = p_user_id
          AND status = 'locked';
    END IF;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to get user profile with relationships
CREATE OR REPLACE FUNCTION get_user_profile(
    p_user_id UUID
)
RETURNS TABLE (
    user_id UUID,
    username VARCHAR,
    full_name VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    user_type user_type_enum,
    status user_status_enum,
    branch_name_en VARCHAR,
    branch_name_ar VARCHAR,
    employee_name VARCHAR,
    position_name_en VARCHAR,
    position_name_ar VARCHAR,
    avatar_url TEXT,
    language_preference VARCHAR,
    timezone VARCHAR,
    theme_preference VARCHAR,
    two_factor_enabled BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    last_login_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as user_id,
        u.username,
        u.full_name,
        u.email,
        u.phone,
        u.user_type,
        u.status,
        b.name_en as branch_name_en,
        b.name_ar as branch_name_ar,
        emp.full_name as employee_name,
        pos.name_en as position_name_en,
        pos.name_ar as position_name_ar,
        u.avatar as avatar_url,
        u.language_preference,
        u.timezone,
        u.theme_preference,
        u.two_factor_enabled,
        u.created_at,
        u.last_login_at
    FROM public.users u
    LEFT JOIN public.branches b ON u.branch_id = b.id
    LEFT JOIN public.hr_employees emp ON u.employee_id = emp.id
    LEFT JOIN public.hr_positions pos ON u.position_id = pos.id
    WHERE u.id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to search users
CREATE OR REPLACE FUNCTION search_users(
    p_search_term TEXT DEFAULT NULL,
    p_branch_id BIGINT DEFAULT NULL,
    p_status user_status_enum DEFAULT NULL,
    p_user_type user_type_enum DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    user_id UUID,
    username VARCHAR,
    full_name VARCHAR,
    email VARCHAR,
    user_type user_type_enum,
    status user_status_enum,
    branch_name VARCHAR,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id as user_id,
        u.username,
        u.full_name,
        u.email,
        u.user_type,
        u.status,
        b.name_en as branch_name,
        u.last_login_at,
        u.created_at
    FROM public.users u
    LEFT JOIN public.branches b ON u.branch_id = b.id
    WHERE 
        (p_search_term IS NULL OR (
            u.full_name ILIKE '%' || p_search_term || '%' OR
            u.username ILIKE '%' || p_search_term || '%' OR
            u.email ILIKE '%' || p_search_term || '%'
        ))
        AND (p_branch_id IS NULL OR u.branch_id = p_branch_id)
        AND (p_status IS NULL OR u.status = p_status)
        AND (p_user_type IS NULL OR u.user_type = p_user_type)
    ORDER BY u.created_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Views for User Management
-- =====================================================

-- View for user overview
CREATE OR REPLACE VIEW user_overview AS
SELECT 
    u.id,
    u.username,
    u.full_name,
    u.email,
    u.user_type,
    u.status,
    u.is_first_login,
    u.failed_login_attempts,
    u.last_login_at,
    u.created_at,
    b.name_en as branch_name,
    emp.full_name as employee_name,
    pos.name_en as position_name,
    CASE 
        WHEN u.status = 'locked' THEN 'Locked'
        WHEN u.failed_login_attempts >= 3 THEN 'Security Alert'
        WHEN u.last_login_at < now() - INTERVAL '30 days' THEN 'Inactive'
        WHEN u.is_first_login THEN 'Pending First Login'
        ELSE 'Active'
    END as security_status
FROM public.users u
LEFT JOIN public.branches b ON u.branch_id = b.id
LEFT JOIN public.hr_employees emp ON u.employee_id = emp.id
LEFT JOIN public.hr_positions pos ON u.position_id = pos.id;

-- View for security monitoring
CREATE OR REPLACE VIEW user_security_monitor AS
SELECT 
    u.id,
    u.username,
    u.full_name,
    u.status,
    u.failed_login_attempts,
    u.locked_at,
    u.last_login_at,
    u.last_password_change,
    u.password_expires_at,
    u.two_factor_enabled,
    CASE 
        WHEN u.password_expires_at < now() THEN 'PASSWORD_EXPIRED'
        WHEN u.password_expires_at < now() + INTERVAL '7 days' THEN 'PASSWORD_EXPIRING'
        WHEN u.last_password_change < now() - INTERVAL '90 days' THEN 'PASSWORD_OLD'
        ELSE 'PASSWORD_OK'
    END as password_status,
    CASE 
        WHEN u.last_login_at IS NULL THEN 'NEVER_LOGGED_IN'
        WHEN u.last_login_at < now() - INTERVAL '90 days' THEN 'LONG_INACTIVE'
        WHEN u.last_login_at < now() - INTERVAL '30 days' THEN 'INACTIVE'
        ELSE 'ACTIVE'
    END as activity_status
FROM public.users u
WHERE u.status != 'archived';

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.users IS 'Core user management system with authentication and authorization - manages all user accounts with comprehensive security and audit features';

COMMENT ON COLUMN public.users.id IS 'Primary key - unique identifier for each user';
COMMENT ON COLUMN public.users.username IS 'Unique username for authentication (alphanumeric, dots, hyphens, underscores)';
COMMENT ON COLUMN public.users.password_hash IS 'Cryptographic hash of user password (bcrypt, scrypt, argon2)';
COMMENT ON COLUMN public.users.salt IS 'Cryptographic salt used with password hash';
COMMENT ON COLUMN public.users.quick_access_code IS 'Unique 6-digit numeric code for quick authentication';
COMMENT ON COLUMN public.users.quick_access_salt IS 'Cryptographic salt for quick access code';
COMMENT ON COLUMN public.users.user_type IS 'Classification of user scope (global or branch-specific)';
COMMENT ON COLUMN public.users.employee_id IS 'Link to HR employee record if user is an employee';
COMMENT ON COLUMN public.users.branch_id IS 'Branch assignment for branch-specific users';
COMMENT ON COLUMN public.users.role_type IS 'Type of role assignment (position-based or custom)';
COMMENT ON COLUMN public.users.position_id IS 'Link to HR position for position-based roles';
COMMENT ON COLUMN public.users.full_name IS 'User full display name';
COMMENT ON COLUMN public.users.email IS 'Unique email address for notifications and recovery';
COMMENT ON COLUMN public.users.phone IS 'Phone number for SMS notifications and 2FA';
COMMENT ON COLUMN public.users.avatar IS 'Primary avatar image URL';
COMMENT ON COLUMN public.users.status IS 'Current account status (active, inactive, suspended, locked, etc.)';
COMMENT ON COLUMN public.users.is_first_login IS 'Flag indicating if user has completed first login';
COMMENT ON COLUMN public.users.failed_login_attempts IS 'Counter for consecutive failed login attempts';
COMMENT ON COLUMN public.users.locked_at IS 'Timestamp when account was locked';
COMMENT ON COLUMN public.users.locked_by IS 'User who locked this account (administrative action)';
COMMENT ON COLUMN public.users.last_login_at IS 'Timestamp of most recent successful login';
COMMENT ON COLUMN public.users.password_expires_at IS 'Timestamp when current password expires';
COMMENT ON COLUMN public.users.last_password_change IS 'Timestamp of most recent password change';
COMMENT ON COLUMN public.users.two_factor_enabled IS 'Flag indicating if 2FA is enabled for this account';
COMMENT ON COLUMN public.users.language_preference IS 'User interface language preference (en, ar, fr, es, de)';
COMMENT ON COLUMN public.users.timezone IS 'User timezone for date/time display';
COMMENT ON COLUMN public.users.theme_preference IS 'UI theme preference (light, dark, auto)';
COMMENT ON COLUMN public.users.notification_preferences IS 'JSON configuration for notification channels';

-- Function comments
COMMENT ON FUNCTION create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, user_type_enum, BIGINT, UUID, VARCHAR, VARCHAR, BIGINT) IS 'Creates a new user account with validation and proper relationship setup';
COMMENT ON FUNCTION authenticate_user(VARCHAR, VARCHAR) IS 'Authenticates user credentials and returns user information for session creation';
COMMENT ON FUNCTION update_login_tracking(UUID, BOOLEAN, INET) IS 'Updates login statistics and handles account locking based on failed attempts';
COMMENT ON FUNCTION get_user_profile(UUID) IS 'Retrieves comprehensive user profile with all related information';
COMMENT ON FUNCTION search_users(TEXT, BIGINT, user_status_enum, user_type_enum, INTEGER, INTEGER) IS 'Advanced user search with filtering and pagination';

-- View comments
COMMENT ON VIEW user_overview IS 'Comprehensive user management view with security status indicators';
COMMENT ON VIEW user_security_monitor IS 'Security-focused view for monitoring password status, activity, and account health';