-- =====================================================
-- USER MANAGEMENT SYSTEM - COMPLETE DATABASE SCHEMA  
-- Updated to align with existing table structure and frontend expectations
-- Execute this entire script in Supabase SQL Editor
-- =====================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- CLEANUP EXISTING COMPONENTS (DROP IF EXISTS)
-- =====================================================

-- Drop all existing components in reverse dependency order
DROP VIEW IF EXISTS user_management_view CASCADE;
DROP VIEW IF EXISTS user_permissions_view CASCADE;
DROP VIEW IF EXISTS position_roles_view CASCADE;

DROP TRIGGER IF EXISTS users_audit_trigger ON users CASCADE;
DROP TRIGGER IF EXISTS sync_roles_on_position_changes ON hr_positions CASCADE;
DROP TRIGGER IF EXISTS update_users_updated_at ON users CASCADE;
DROP TRIGGER IF EXISTS update_user_roles_updated_at ON user_roles CASCADE;
DROP TRIGGER IF EXISTS update_role_permissions_updated_at ON role_permissions CASCADE;
DROP TRIGGER IF EXISTS update_app_functions_updated_at ON app_functions CASCADE;

DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS hash_password(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS verify_password(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS generate_salt() CASCADE;
DROP FUNCTION IF EXISTS generate_unique_quick_access_code() CASCADE;
DROP FUNCTION IF EXISTS sync_user_roles_from_positions() CASCADE;
DROP FUNCTION IF EXISTS refresh_user_roles_from_positions() CASCADE;
DROP FUNCTION IF EXISTS log_user_action() CASCADE;
DROP FUNCTION IF EXISTS register_app_function(TEXT, TEXT, TEXT, TEXT, BOOLEAN) CASCADE;
DROP FUNCTION IF EXISTS get_or_create_app_function(TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS sync_app_functions_from_components(JSONB) CASCADE;
DROP FUNCTION IF EXISTS register_system_role(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS setup_role_permissions(TEXT, JSONB) CASCADE;
DROP FUNCTION IF EXISTS create_system_admin(TEXT, TEXT, TEXT, role_type_enum, user_type_enum) CASCADE;
DROP FUNCTION IF EXISTS create_user(TEXT, TEXT, role_type_enum, user_type_enum, BIGINT, UUID, UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS is_quick_access_code_available(TEXT) CASCADE;
DROP FUNCTION IF EXISTS get_quick_access_stats() CASCADE;

DROP TABLE IF EXISTS user_password_history CASCADE;
DROP TABLE IF EXISTS user_audit_logs CASCADE;
DROP TABLE IF EXISTS user_sessions CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS role_permissions CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS app_functions CASCADE;

DROP TYPE IF EXISTS user_type_enum CASCADE;
DROP TYPE IF EXISTS role_type_enum CASCADE;
DROP TYPE IF EXISTS user_status_enum CASCADE;

-- Clean up existing storage policies for user avatars
DROP POLICY IF EXISTS "Allow public read access to user avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to upload avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to update their own avatars" ON storage.objects;
DROP POLICY IF EXISTS "Allow users to delete their own avatars" ON storage.objects;

-- Remove existing indexes if they exist
DROP INDEX IF EXISTS idx_users_username CASCADE;
DROP INDEX IF EXISTS idx_users_quick_access CASCADE;
DROP INDEX IF EXISTS idx_users_status CASCADE;
DROP INDEX IF EXISTS idx_users_role_type CASCADE;
DROP INDEX IF EXISTS idx_users_employee_id CASCADE;
DROP INDEX IF EXISTS idx_users_branch_id CASCADE;
DROP INDEX IF EXISTS idx_users_created_at CASCADE;
DROP INDEX IF EXISTS idx_users_last_login CASCADE;
DROP INDEX IF EXISTS idx_role_permissions_role_id CASCADE;
DROP INDEX IF EXISTS idx_role_permissions_function_id CASCADE;
DROP INDEX IF EXISTS idx_user_sessions_user_id CASCADE;
DROP INDEX IF EXISTS idx_user_sessions_token CASCADE;
DROP INDEX IF EXISTS idx_user_sessions_active CASCADE;
DROP INDEX IF EXISTS idx_user_audit_logs_user_id CASCADE;
DROP INDEX IF EXISTS idx_user_audit_logs_action CASCADE;
DROP INDEX IF EXISTS idx_user_audit_logs_created_at CASCADE;
DROP INDEX IF EXISTS idx_password_history_user_created CASCADE;

-- =====================================================
-- STORAGE SETUP FOR AVATARS
-- =====================================================

-- Create storage bucket for user avatars
INSERT INTO storage.buckets (id, name, public) VALUES ('user-avatars', 'user-avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Set up storage policies for user avatars
CREATE POLICY "Allow public read access to user avatars" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'user-avatars');

CREATE POLICY "Allow authenticated users to upload avatars" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'user-avatars' AND auth.role() = 'authenticated');

CREATE POLICY "Allow users to update their own avatars" 
ON storage.objects FOR UPDATE 
USING (bucket_id = 'user-avatars' AND auth.role() = 'authenticated');

CREATE POLICY "Allow users to delete their own avatars" 
ON storage.objects FOR DELETE 
USING (bucket_id = 'user-avatars' AND auth.role() = 'authenticated');

-- =====================================================
-- CORE USER MANAGEMENT TABLES
-- =====================================================

-- User Types and Status Enums
CREATE TYPE user_type_enum AS ENUM ('global', 'branch_specific');
CREATE TYPE role_type_enum AS ENUM ('Master Admin', 'Admin', 'Position-based');
CREATE TYPE user_status_enum AS ENUM ('active', 'inactive', 'locked');

-- Application Functions Table (for permission management)
CREATE TABLE app_functions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    function_name VARCHAR(100) NOT NULL UNIQUE,
    function_code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    category VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Dynamic function registration for components
CREATE OR REPLACE FUNCTION register_app_function(
    p_function_name TEXT,
    p_function_code TEXT,
    p_description TEXT DEFAULT NULL,
    p_category TEXT DEFAULT 'Application',
    p_enabled BOOLEAN DEFAULT true
) RETURNS UUID AS $$
DECLARE
    new_id UUID;
BEGIN
    -- Check if function already exists
    IF EXISTS (SELECT 1 FROM app_functions WHERE function_code = p_function_code) THEN
        -- Update existing function
        UPDATE app_functions 
        SET function_name = p_function_name,
            description = COALESCE(p_description, description),
            category = p_category,
            is_active = p_enabled,
            updated_at = CURRENT_TIMESTAMP
        WHERE function_code = p_function_code
        RETURNING id INTO new_id;
        
        RETURN new_id;
    ELSE
        -- Insert new function
        INSERT INTO app_functions (function_name, function_code, description, category, is_active)
        VALUES (p_function_name, p_function_code, p_description, p_category, p_enabled)
        RETURNING id INTO new_id;
        
        RETURN new_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to get or create app function by code
CREATE OR REPLACE FUNCTION get_or_create_app_function(
    p_function_code TEXT,
    p_function_name TEXT DEFAULT NULL,
    p_description TEXT DEFAULT NULL,
    p_category TEXT DEFAULT 'Application'
) RETURNS UUID AS $$
DECLARE
    function_id UUID;
BEGIN
    -- Try to get existing function
    SELECT id INTO function_id 
    FROM app_functions 
    WHERE function_code = p_function_code;
    
    -- If not found, create it
    IF function_id IS NULL THEN
        function_id := register_app_function(
            COALESCE(p_function_name, initcap(replace(p_function_code, '_', ' '))),
            p_function_code,
            p_description,
            p_category
        );
    END IF;
    
    RETURN function_id;
END;
$$ LANGUAGE plpgsql;

-- Function to discover and register functions from component metadata
CREATE OR REPLACE FUNCTION sync_app_functions_from_components(
    component_metadata JSONB
) RETURNS TEXT AS $$
DECLARE
    component JSONB;
    function_record JSONB;
    result_count INTEGER := 0;
    result_text TEXT := '';
BEGIN
    -- Loop through each component in the metadata
    FOR component IN SELECT jsonb_array_elements(component_metadata->'components')
    LOOP
        -- Loop through functions in each component
        FOR function_record IN SELECT jsonb_array_elements(component->'functions')
        LOOP
            -- Register each function
            PERFORM register_app_function(
                function_record->>'name',
                function_record->>'code',
                function_record->>'description',
                COALESCE(function_record->>'category', component->>'category', 'Application')
            );
            
            result_count := result_count + 1;
        END LOOP;
    END LOOP;
    
    result_text := format('Synchronized %s app functions from component metadata', result_count);
    RETURN result_text;
END;
$$ LANGUAGE plpgsql;

-- App Functions (now dynamically manageable - no hard-coded entries)
-- Components can register themselves through the registration function
-- Or can be populated from component discovery system

-- Note: Initially empty - functions should be registered dynamically
-- through the register_app_function() stored procedure

-- Example of how to register functions dynamically:
-- SELECT register_app_function('User Management', 'USER_MGMT', 'Manage user accounts', 'Administration');
-- SELECT register_app_function('HR Master', 'HR_MASTER', 'HR management dashboard', 'Master Data');

-- =====================================================
-- CREATE ESSENTIAL APP FUNCTIONS IN SCHEMA
-- =====================================================

-- Create essential app functions that are needed for basic system operation
DO $$
BEGIN
    -- Core system functions
    PERFORM register_app_function(
        'Dashboard Access', 
        'DASHBOARD', 
        'Main dashboard and navigation access', 
        'System'
    );
    
    PERFORM register_app_function(
        'User Management', 
        'USER_MGMT', 
        'Manage user accounts and permissions', 
        'Administration'
    );
    
    PERFORM register_app_function(
        'System Settings', 
        'SETTINGS', 
        'System configuration and preferences', 
        'Administration'
    );
    
    -- Master Data functions
    PERFORM register_app_function(
        'Branch Master', 
        'BRANCH_MASTER', 
        'Manage company branches and locations', 
        'Master Data'
    );
    
    PERFORM register_app_function(
        'HR Master', 
        'HR_MASTER', 
        'Human resources master data management', 
        'Master Data'
    );
    
    PERFORM register_app_function(
        'Task Master', 
        'TASK_MASTER', 
        'Task and workflow management', 
        'Master Data'
    );
    
    RAISE NOTICE 'Essential app functions created: Dashboard, User Management, System Settings, Master Data modules';
END $$;

-- User Roles Table (simplified to match frontend expectations)
CREATE TABLE user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_name VARCHAR(100) NOT NULL UNIQUE,
    role_code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_system_role BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

-- User roles are now completely dynamic - no hard-coded entries
-- System roles and position-based roles will be created through:
-- 1. bootstrap-app-functions.sql for initial system roles
-- 2. Automatic sync from hr_positions table via triggers
-- 3. Manual registration through register_user_role() function if needed

-- Function to register system roles dynamically
CREATE OR REPLACE FUNCTION register_system_role(
    p_role_name TEXT,
    p_role_code TEXT,
    p_description TEXT
) RETURNS UUID AS $$
DECLARE
    new_role_id UUID;
BEGIN
    INSERT INTO user_roles (role_name, role_code, description, is_system_role)
    VALUES (p_role_name, p_role_code, p_description, true)
    ON CONFLICT (role_name) DO UPDATE SET
        role_code = p_role_code,
        description = p_description,
        updated_at = NOW()
    RETURNING id INTO new_role_id;
    
    RETURN new_role_id;
END;
$$ LANGUAGE plpgsql;

-- Automatically populate user roles from HR positions table when they exist
-- This ensures roles stay synchronized with your organizational structure
INSERT INTO user_roles (role_name, role_code, description, is_system_role)
SELECT 
    hp.position_title_en as role_name,
    UPPER(REPLACE(REPLACE(hp.position_title_en, ' ', '_'), '/', '_')) as role_code,
    CONCAT('Access level for ', hp.position_title_en, ' position') as description,
    false as is_system_role
FROM hr_positions hp
WHERE hp.position_title_en IS NOT NULL
ON CONFLICT (role_name) DO NOTHING;

-- =====================================================
-- CREATE ESSENTIAL SYSTEM ROLES IN SCHEMA
-- =====================================================

-- Create essential system roles that are needed for admin users
DO $$
BEGIN
    -- Create Master Admin role
    PERFORM register_system_role(
        'Master Admin', 
        'MASTER_ADMIN', 
        'Full system access with all permissions'
    );
    
    -- Create Admin role
    PERFORM register_system_role(
        'Admin', 
        'ADMIN', 
        'Administrative access with most permissions'
    );
    
    RAISE NOTICE 'Essential system roles created: Master Admin, Admin';
END $$;

-- Role Permissions Table (maps roles to app functions with specific permissions)
-- Matching CreateUserRoles component permission structure: View, Add, Edit, Delete, Export
CREATE TABLE role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES user_roles(id) ON DELETE CASCADE,
    function_id UUID NOT NULL REFERENCES app_functions(id) ON DELETE CASCADE,
    can_view BOOLEAN DEFAULT false,
    can_add BOOLEAN DEFAULT false,
    can_edit BOOLEAN DEFAULT false,
    can_delete BOOLEAN DEFAULT false,
    can_export BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(role_id, function_id)
);

-- Users Table (aligned with existing schema conventions and frontend expectations)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(100) NOT NULL,
    quick_access_code VARCHAR(6) NOT NULL UNIQUE, -- Added UNIQUE constraint
    quick_access_salt VARCHAR(100) NOT NULL,
    
    -- User Classification
    user_type user_type_enum NOT NULL DEFAULT 'branch_specific',
    
    -- Employee & Branch Association (matching existing schema)
    employee_id UUID REFERENCES hr_employees(id) ON DELETE SET NULL,
    branch_id BIGINT REFERENCES branches(id) ON DELETE SET NULL, -- Using bigint to match existing branches table
    
    -- Role Assignment (simplified for frontend compatibility)
    role_type role_type_enum DEFAULT 'Position-based',
    position_id UUID, -- Will reference hr_positions when available
    
    -- Avatar Management
    avatar TEXT, -- Main avatar URL for frontend compatibility
    avatar_small_url TEXT,
    avatar_medium_url TEXT,
    avatar_large_url TEXT,
    
    -- Account Status
    status user_status_enum DEFAULT 'active',
    is_first_login BOOLEAN DEFAULT true,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_at TIMESTAMP WITH TIME ZONE,
    locked_by UUID REFERENCES users(id),
    
    -- Session Management
    last_login_at TIMESTAMP WITH TIME ZONE,
    
    -- Password Management
    password_expires_at TIMESTAMP WITH TIME ZONE,
    last_password_change TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Audit Fields (matching existing schema patterns)
    created_by BIGINT, -- Can reference different user systems
    updated_by BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT users_employee_branch_check CHECK (
        (user_type = 'global') OR 
        (user_type = 'branch_specific' AND branch_id IS NOT NULL)
    ),
    CONSTRAINT users_quick_access_length CHECK (LENGTH(quick_access_code) = 6),
    CONSTRAINT users_quick_access_numeric CHECK (quick_access_code ~ '^[0-9]{6}$')
);

-- User Sessions Table (for login tracking)
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) NOT NULL UNIQUE,
    login_method VARCHAR(20) NOT NULL CHECK (login_method IN ('quick_access', 'username_password')),
    ip_address INET,
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE
);

-- User Audit Logs Table (comprehensive logging)
CREATE TABLE user_audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    target_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(100) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    performed_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Password History Table (for password policy enforcement)
CREATE TABLE user_password_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    password_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- FUNCTIONS AND TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Password utility functions
CREATE OR REPLACE FUNCTION hash_password(password TEXT, salt TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN crypt(password, salt);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION verify_password(password TEXT, hash TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN hash = crypt(password, hash);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_salt()
RETURNS TEXT AS $$
BEGIN
    RETURN gen_salt('bf', 10);
END;
$$ LANGUAGE plpgsql;

-- Function to generate unique quick access code
CREATE OR REPLACE FUNCTION generate_unique_quick_access_code()
RETURNS TEXT AS $$
DECLARE
    new_code TEXT;
    code_exists BOOLEAN;
    max_attempts INTEGER := 1000;
    attempt_count INTEGER := 0;
BEGIN
    LOOP
        -- Generate random 6-digit code
        new_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
        
        -- Check if code already exists
        SELECT EXISTS(SELECT 1 FROM users WHERE quick_access_code = new_code) INTO code_exists;
        
        -- If code doesn't exist, return it
        IF NOT code_exists THEN
            RETURN new_code;
        END IF;
        
        -- Increment attempt counter to prevent infinite loops
        attempt_count := attempt_count + 1;
        IF attempt_count >= max_attempts THEN
            RAISE EXCEPTION 'Unable to generate unique quick access code after % attempts', max_attempts;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to sync user roles from HR positions
CREATE OR REPLACE FUNCTION sync_user_roles_from_positions()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        -- Insert or update user role based on position
        INSERT INTO user_roles (
            role_name, 
            role_code, 
            description, 
            is_system_role,
            updated_at
        ) VALUES (
            NEW.position_title_en,
            UPPER(REPLACE(REPLACE(NEW.position_title_en, ' ', '_'), '/', '_')),
            CONCAT('Access level for ', NEW.position_title_en, ' position'),
            false,
            NOW()
        )
        ON CONFLICT (role_name) DO UPDATE SET
            role_code = UPPER(REPLACE(REPLACE(NEW.position_title_en, ' ', '_'), '/', '_')),
            description = CONCAT('Access level for ', NEW.position_title_en, ' position'),
            updated_at = NOW();
        
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        -- Optionally handle deletion - mark role as inactive instead of deleting
        UPDATE user_roles 
        SET is_active = false, updated_at = NOW()
        WHERE role_name = OLD.position_title_en 
        AND is_system_role = false;
        
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to manually refresh all user roles from positions (if needed)
CREATE OR REPLACE FUNCTION refresh_user_roles_from_positions()
RETURNS INTEGER AS $$
DECLARE
    roles_updated INTEGER := 0;
BEGIN
    -- Insert new roles from positions that don't exist yet
    INSERT INTO user_roles (role_name, role_code, description, is_system_role)
    SELECT 
        hp.position_title_en,
        UPPER(REPLACE(REPLACE(hp.position_title_en, ' ', '_'), '/', '_')),
        CONCAT('Access level for ', hp.position_title_en, ' position'),
        false
    FROM hr_positions hp
    WHERE hp.position_title_en IS NOT NULL
    AND NOT EXISTS (
        SELECT 1 FROM user_roles ur 
        WHERE ur.role_name = hp.position_title_en
    );
    
    GET DIAGNOSTICS roles_updated = ROW_COUNT;
    
    -- Update existing roles to ensure they're active
    UPDATE user_roles 
    SET is_active = true, updated_at = NOW()
    WHERE role_name IN (
        SELECT position_title_en 
        FROM hr_positions 
        WHERE position_title_en IS NOT NULL
    )
    AND is_system_role = false;
    
    RETURN roles_updated;
END;
$$ LANGUAGE plpgsql;

-- Function to log user actions
CREATE OR REPLACE FUNCTION log_user_action()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO user_audit_logs (
            user_id, action, table_name, record_id, old_values, performed_by
        ) VALUES (
            OLD.id, TG_OP, TG_TABLE_NAME, OLD.id, to_jsonb(OLD), 
            CASE WHEN OLD.updated_by IS NOT NULL THEN uuid_generate_v4() ELSE NULL END
        );
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO user_audit_logs (
            user_id, action, table_name, record_id, old_values, new_values, performed_by
        ) VALUES (
            NEW.id, TG_OP, TG_TABLE_NAME, NEW.id, to_jsonb(OLD), to_jsonb(NEW),
            CASE WHEN NEW.updated_by IS NOT NULL THEN uuid_generate_v4() ELSE NULL END
        );
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO user_audit_logs (
            user_id, action, table_name, record_id, new_values, performed_by
        ) VALUES (
            NEW.id, TG_OP, TG_TABLE_NAME, NEW.id, to_jsonb(NEW),
            CASE WHEN NEW.created_by IS NOT NULL THEN uuid_generate_v4() ELSE NULL END
        );
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_roles_updated_at BEFORE UPDATE ON user_roles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_role_permissions_updated_at BEFORE UPDATE ON role_permissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_app_functions_updated_at BEFORE UPDATE ON app_functions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Apply audit logging trigger
CREATE TRIGGER users_audit_trigger
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION log_user_action();

-- Trigger to automatically sync user roles when HR positions change
CREATE TRIGGER sync_roles_on_position_changes
    AFTER INSERT OR UPDATE OR DELETE ON hr_positions
    FOR EACH ROW EXECUTE FUNCTION sync_user_roles_from_positions();

-- =====================================================
-- VIEWS FOR FRONTEND COMPATIBILITY
-- =====================================================

-- User Management View (matching frontend expected structure)
CREATE OR REPLACE VIEW user_management_view AS
SELECT 
    u.id,
    u.username,
    
    -- Employee name (from hr_employees table)
    COALESCE(he.name, 'Unknown Employee') as employee_name,
    
    -- Branch name (from branches table, supporting both languages)
    COALESCE(b.name_en, b.name_ar, 'Unknown Branch') as branch_name,
    
    -- Role type (simplified for frontend)
    u.role_type,
    
    -- Status and account info
    u.status,
    u.avatar,
    u.last_login_at as last_login,
    u.is_first_login,
    u.failed_login_attempts,
    
    -- Additional useful fields
    u.user_type,
    u.employee_id,
    u.branch_id,
    u.position_id,
    u.created_at,
    u.updated_at
    
FROM users u
LEFT JOIN hr_employees he ON u.employee_id = he.id
LEFT JOIN branches b ON u.branch_id = b.id;

-- User Permissions View (for role-based access control)
CREATE OR REPLACE VIEW user_permissions_view AS
SELECT 
    u.id as user_id,
    u.username,
    ur.role_name,
    af.function_name,
    af.function_code,
    rp.can_view,
    rp.can_add,
    rp.can_edit,
    rp.can_delete,
    rp.can_export
FROM users u
LEFT JOIN user_roles ur ON ur.role_code = 
    CASE 
        WHEN u.role_type = 'Master Admin' THEN 'MASTER_ADMIN'
        WHEN u.role_type = 'Admin' THEN 'ADMIN'
        ELSE 'EMPLOYEE'
    END
LEFT JOIN role_permissions rp ON ur.id = rp.role_id
LEFT JOIN app_functions af ON rp.function_id = af.id
WHERE u.status = 'active' AND (ur.is_active = true OR ur.is_active IS NULL) AND af.is_active = true;

-- Position-based Roles View (connects user roles to HR positions)
CREATE OR REPLACE VIEW position_roles_view AS
SELECT 
    ur.id as role_id,
    ur.role_name,
    ur.role_code,
    ur.description as role_description,
    ur.is_system_role,
    
    -- Position information (if available)
    hp.id as position_id,
    hp.position_title_en,
    hp.position_title_ar,
    
    -- Department information
    hd.id as department_id,
    hd.department_name_en,
    hd.department_name_ar,
    
    -- Level information
    hl.id as level_id,
    hl.level_name_en,
    hl.level_name_ar,
    hl.level_order
    
FROM user_roles ur
LEFT JOIN hr_positions hp ON UPPER(REPLACE(REPLACE(hp.position_title_en, ' ', '_'), '/', '_')) = ur.role_code
LEFT JOIN hr_departments hd ON hp.department_id = hd.id
LEFT JOIN hr_levels hl ON hp.level_id = hl.id
ORDER BY 
    CASE 
        WHEN ur.is_system_role = true THEN 0 
        ELSE hl.level_order 
    END,
    ur.role_name;

-- =====================================================
-- DYNAMIC PERMISSIONS SETUP
-- =====================================================

-- Function to setup role permissions dynamically
CREATE OR REPLACE FUNCTION setup_role_permissions(
    p_role_code TEXT,
    p_permissions JSONB DEFAULT '{"can_view": true, "can_add": false, "can_edit": false, "can_delete": false, "can_export": false}'
) RETURNS INTEGER AS $$
DECLARE
    v_role_id UUID;
    func_record RECORD;
    permissions_set INTEGER := 0;
BEGIN
    -- Get role ID
    SELECT id INTO v_role_id FROM user_roles WHERE role_code = p_role_code;
    
    IF v_role_id IS NULL THEN
        RAISE NOTICE 'Role % not found', p_role_code;
        RETURN 0;
    END IF;
    
    -- Set permissions for all active functions
    FOR func_record IN SELECT id FROM app_functions WHERE is_active = true LOOP
        INSERT INTO role_permissions (
            role_id, 
            function_id, 
            can_view, 
            can_add, 
            can_edit, 
            can_delete, 
            can_export
        ) VALUES (
            v_role_id, 
            func_record.id,
            COALESCE((p_permissions->>'can_view')::BOOLEAN, false),
            COALESCE((p_permissions->>'can_add')::BOOLEAN, false),
            COALESCE((p_permissions->>'can_edit')::BOOLEAN, false),
            COALESCE((p_permissions->>'can_delete')::BOOLEAN, false),
            COALESCE((p_permissions->>'can_export')::BOOLEAN, false)
        ) ON CONFLICT (role_id, function_id) DO UPDATE SET
            can_view = COALESCE((p_permissions->>'can_view')::BOOLEAN, false),
            can_add = COALESCE((p_permissions->>'can_add')::BOOLEAN, false),
            can_edit = COALESCE((p_permissions->>'can_edit')::BOOLEAN, false),
            can_delete = COALESCE((p_permissions->>'can_delete')::BOOLEAN, false),
            can_export = COALESCE((p_permissions->>'can_export')::BOOLEAN, false),
            updated_at = NOW();
        
        permissions_set := permissions_set + 1;
    END LOOP;
    
    RETURN permissions_set;
END;
$$ LANGUAGE plpgsql;

-- Note: Default permissions setup is now handled through:
-- 1. bootstrap-app-functions.sql - which will create system roles and their permissions
-- 2. setup_role_permissions() function for dynamic permission assignment
-- 3. CreateUserRoles component in frontend for interactive permission management

-- =====================================================
-- DYNAMIC USER CREATION FUNCTIONS
-- =====================================================

-- Function to create system admin user dynamically
CREATE OR REPLACE FUNCTION create_system_admin(
    p_username TEXT,
    p_password TEXT,
    p_quick_access_code TEXT DEFAULT NULL, -- Made optional
    p_role_type role_type_enum DEFAULT 'Master Admin',
    p_user_type user_type_enum DEFAULT 'global'
) RETURNS UUID AS $$
DECLARE
    password_salt TEXT;
    qr_salt TEXT;
    admin_user_id UUID;
    main_branch_id BIGINT;
    final_quick_code TEXT;
BEGIN
    -- Get main branch ID (or any branch)
    SELECT id INTO main_branch_id FROM branches WHERE is_main_branch = true LIMIT 1;
    IF main_branch_id IS NULL THEN
        SELECT id INTO main_branch_id FROM branches LIMIT 1;
    END IF;
    
    -- Generate salts
    password_salt := generate_salt();
    qr_salt := generate_salt();
    
    -- Use provided quick access code or generate unique one
    IF p_quick_access_code IS NOT NULL THEN
        -- Check if provided code is already in use
        IF EXISTS (SELECT 1 FROM users WHERE quick_access_code = p_quick_access_code) THEN
            RAISE EXCEPTION 'Quick access code % is already in use', p_quick_access_code;
        END IF;
        final_quick_code := p_quick_access_code;
    ELSE
        final_quick_code := generate_unique_quick_access_code();
    END IF;
    
    -- Insert the admin user
    INSERT INTO users (
        username, 
        password_hash, 
        salt,
        quick_access_code, 
        quick_access_salt,
        user_type,
        branch_id,
        role_type, 
        status,
        is_first_login,
        password_expires_at
    ) VALUES (
        p_username,
        hash_password(p_password, password_salt),
        password_salt,
        final_quick_code,
        hash_password(final_quick_code, qr_salt),
        p_user_type,
        main_branch_id,
        p_role_type,
        'active',
        true,
        NOW() + INTERVAL '90 days'
    ) RETURNING id INTO admin_user_id;
    
    RAISE NOTICE 'System admin user created with ID: %', admin_user_id;
    RAISE NOTICE 'Username: %, Role: %, Quick Access: %', p_username, p_role_type, final_quick_code;
    
    RETURN admin_user_id;
END;
$$ LANGUAGE plpgsql;

-- Function to create regular user with unique quick access code
CREATE OR REPLACE FUNCTION create_user(
    p_username TEXT,
    p_password TEXT,
    p_role_type role_type_enum DEFAULT 'Position-based',
    p_user_type user_type_enum DEFAULT 'branch_specific',
    p_branch_id BIGINT DEFAULT NULL,
    p_employee_id UUID DEFAULT NULL,
    p_position_id UUID DEFAULT NULL,
    p_quick_access_code TEXT DEFAULT NULL -- Optional - will generate if not provided
) RETURNS JSONB AS $$
DECLARE
    password_salt TEXT;
    qr_salt TEXT;
    new_user_id UUID;
    final_quick_code TEXT;
    default_branch_id BIGINT;
BEGIN
    -- Generate salts
    password_salt := generate_salt();
    qr_salt := generate_salt();
    
    -- Handle branch assignment
    IF p_user_type = 'branch_specific' AND p_branch_id IS NULL THEN
        -- Get default branch
        SELECT id INTO default_branch_id FROM branches WHERE is_main_branch = true LIMIT 1;
        IF default_branch_id IS NULL THEN
            SELECT id INTO default_branch_id FROM branches LIMIT 1;
        END IF;
        p_branch_id := default_branch_id;
    END IF;
    
    -- Handle quick access code
    IF p_quick_access_code IS NOT NULL THEN
        -- Validate format
        IF LENGTH(p_quick_access_code) != 6 OR p_quick_access_code !~ '^[0-9]{6}$' THEN
            RAISE EXCEPTION 'Quick access code must be exactly 6 digits';
        END IF;
        
        -- Check uniqueness
        IF EXISTS (SELECT 1 FROM users WHERE quick_access_code = p_quick_access_code) THEN
            RAISE EXCEPTION 'Quick access code % is already in use', p_quick_access_code;
        END IF;
        final_quick_code := p_quick_access_code;
    ELSE
        final_quick_code := generate_unique_quick_access_code();
    END IF;
    
    -- Insert the user
    INSERT INTO users (
        username, 
        password_hash, 
        salt,
        quick_access_code, 
        quick_access_salt,
        user_type,
        branch_id,
        employee_id,
        position_id,
        role_type, 
        status,
        is_first_login,
        password_expires_at
    ) VALUES (
        p_username,
        hash_password(p_password, password_salt),
        password_salt,
        final_quick_code,
        hash_password(final_quick_code, qr_salt),
        p_user_type,
        p_branch_id,
        p_employee_id,
        p_position_id,
        p_role_type,
        'active',
        true,
        NOW() + INTERVAL '90 days'
    ) RETURNING id INTO new_user_id;
    
    -- Return user details including the generated quick access code
    RETURN jsonb_build_object(
        'user_id', new_user_id,
        'username', p_username,
        'quick_access_code', final_quick_code,
        'role_type', p_role_type,
        'user_type', p_user_type,
        'branch_id', p_branch_id,
        'success', true,
        'message', 'User created successfully'
    );
END;
$$ LANGUAGE plpgsql;

-- Function to check if quick access code is available
CREATE OR REPLACE FUNCTION is_quick_access_code_available(
    p_quick_access_code TEXT
) RETURNS BOOLEAN AS $$
BEGIN
    -- Validate format first
    IF LENGTH(p_quick_access_code) != 6 OR p_quick_access_code !~ '^[0-9]{6}$' THEN
        RETURN false;
    END IF;
    
    -- Check if code exists
    RETURN NOT EXISTS (SELECT 1 FROM users WHERE quick_access_code = p_quick_access_code);
END;
$$ LANGUAGE plpgsql;

-- Function to get quick access code usage statistics
CREATE OR REPLACE FUNCTION get_quick_access_stats()
RETURNS JSONB AS $$
DECLARE
    total_possible INTEGER := 1000000; -- 000000 to 999999
    total_used INTEGER;
    available INTEGER;
    usage_percentage NUMERIC;
BEGIN
    SELECT COUNT(*) INTO total_used FROM users;
    available := total_possible - total_used;
    usage_percentage := ROUND((total_used::NUMERIC / total_possible::NUMERIC) * 100, 4);
    
    RETURN jsonb_build_object(
        'total_possible', total_possible,
        'total_used', total_used,
        'available', available,
        'usage_percentage', usage_percentage,
        'collision_risk', CASE 
            WHEN usage_percentage < 50 THEN 'Low'
            WHEN usage_percentage < 80 THEN 'Medium' 
            WHEN usage_percentage < 95 THEN 'High'
            ELSE 'Critical'
        END
    );
END;
$$ LANGUAGE plpgsql;

-- Note: Default master admin user creation is now handled through:
-- 1. bootstrap-app-functions.sql - which will create the initial system admin
-- 2. create_system_admin() function for creating additional admin users
-- 3. CreateUser component in frontend for regular user creation

-- =====================================================
-- CREATE DEFAULT MASTER ADMIN USER IN SCHEMA
-- =====================================================

-- Create default master admin user during schema setup
DO $$
DECLARE
    admin_user_id UUID;
BEGIN
    -- Only create if no users exist yet
    IF NOT EXISTS (SELECT 1 FROM users LIMIT 1) THEN
        -- Create the default master admin user
        SELECT create_system_admin(
            'madmin',              -- username
            '@Madmin709',          -- password
            '491709',              -- quick access code
            'Master Admin'::role_type_enum,  -- role type
            'global'::user_type_enum         -- user type
        ) INTO admin_user_id;
        
        RAISE NOTICE '=== DEFAULT MASTER ADMIN CREATED ===';
        RAISE NOTICE 'Username: madmin';
        RAISE NOTICE 'Password: @Madmin709';
        RAISE NOTICE 'Quick Access: 491709';
        RAISE NOTICE 'User ID: %', admin_user_id;
        RAISE NOTICE '=====================================';
    ELSE
        RAISE NOTICE 'Users already exist - skipping default master admin creation';
    END IF;
END $$;

-- =====================================================
-- SETUP DEFAULT PERMISSIONS FOR MASTER ADMIN
-- =====================================================

-- Grant all permissions to Master Admin role for all available functions
DO $$
DECLARE
    permissions_count INTEGER;
BEGIN
    -- Setup full permissions for Master Admin
    SELECT setup_role_permissions(
        'MASTER_ADMIN',
        '{"can_view": true, "can_add": true, "can_edit": true, "can_delete": true, "can_export": true}'::JSONB
    ) INTO permissions_count;
    
    -- Setup limited permissions for Admin role
    SELECT setup_role_permissions(
        'ADMIN',
        '{"can_view": true, "can_add": true, "can_edit": true, "can_delete": false, "can_export": true}'::JSONB
    ) INTO permissions_count;
    
    RAISE NOTICE 'Default permissions configured for Master Admin and Admin roles';
    RAISE NOTICE 'Master Admin has full permissions on all % functions', permissions_count;
END $$;

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Users table indexes
CREATE INDEX idx_users_username ON users(username);
CREATE UNIQUE INDEX idx_users_quick_access ON users(quick_access_code);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_role_type ON users(role_type);
CREATE INDEX idx_users_employee_id ON users(employee_id);
CREATE INDEX idx_users_branch_id ON users(branch_id);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_last_login ON users(last_login_at);

-- Role permissions indexes
CREATE INDEX idx_role_permissions_role_id ON role_permissions(role_id);
CREATE INDEX idx_role_permissions_function_id ON role_permissions(function_id);

-- User sessions indexes
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX idx_user_sessions_active ON user_sessions(is_active);

-- User audit logs indexes
CREATE INDEX idx_user_audit_logs_user_id ON user_audit_logs(user_id);
CREATE INDEX idx_user_audit_logs_action ON user_audit_logs(action);
CREATE INDEX idx_user_audit_logs_created_at ON user_audit_logs(created_at);

-- Password history index
CREATE INDEX idx_password_history_user_created ON user_password_history(user_id, created_at DESC);

-- =====================================================
-- VERIFICATION AND SETUP SUMMARY
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '=== DYNAMIC USER MANAGEMENT SYSTEM SETUP COMPLETE ===';
    RAISE NOTICE 'Tables Created: %', (
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name IN ('users', 'user_roles', 'role_permissions', 'app_functions', 'user_audit_logs')
    );
    RAISE NOTICE 'Security Features: UNIQUE quick access codes, duplicate prevention, auto-generation';
    RAISE NOTICE 'Dynamic Functions Available: register_app_function, create_user, generate_unique_quick_access_code';
    RAISE NOTICE 'Views Created: user_management_view, user_permissions_view, position_roles_view';
    RAISE NOTICE 'Storage Bucket: user-avatars configured';
    RAISE NOTICE 'Quick Access Security: Enforced uniqueness with automatic conflict resolution';
    RAISE NOTICE '=========================================================';
END $$;

-- Display setup summary (all tables should be empty initially)
SELECT 
    'Dynamic User Management Setup' as summary_type,
    jsonb_build_object(
        'total_users', (SELECT COUNT(*) FROM users),
        'total_roles', (SELECT COUNT(*) FROM user_roles),
        'total_functions', (SELECT COUNT(*) FROM app_functions),
        'total_permissions', (SELECT COUNT(*) FROM role_permissions),
        'hr_positions_available', (SELECT COUNT(*) FROM hr_positions WHERE position_title_en IS NOT NULL),
        'dynamic_functions_ready', true,
        'bootstrap_script_required', true,
        'main_view_ready', (SELECT EXISTS(SELECT 1 FROM information_schema.views WHERE table_name = 'user_management_view'))
    ) as details;

-- =====================================================
-- END OF UPDATED USER MANAGEMENT SCHEMA
-- =====================================================