-- =====================================================
-- Table: user_roles
-- Description: Role-based access control (RBAC) system for user authorization
-- This table defines roles that can be assigned to users for permission management
-- =====================================================

-- Create user_roles table
CREATE TABLE public.user_roles (
    -- Primary key with UUID generation using extensions
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    
    -- Role identification
    role_name CHARACTER VARYING(100) NOT NULL,
    role_code CHARACTER VARYING(50) NOT NULL,
    description TEXT NULL,
    
    -- Role properties
    is_system_role BOOLEAN NULL DEFAULT false,
    is_active BOOLEAN NULL DEFAULT true,
    
    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    -- Audit user tracking
    created_by UUID NULL,
    updated_by UUID NULL,
    
    -- Primary key constraint
    CONSTRAINT user_roles_pkey PRIMARY KEY (id),
    
    -- Unique constraints for role identification
    CONSTRAINT user_roles_role_code_key UNIQUE (role_code),
    CONSTRAINT user_roles_role_name_key UNIQUE (role_name),
    
    -- Check constraints for data integrity
    CONSTRAINT chk_role_name_not_empty 
        CHECK (length(trim(role_name)) > 0),
    
    CONSTRAINT chk_role_code_not_empty 
        CHECK (length(trim(role_code)) > 0),
    
    -- Role code format validation (alphanumeric, underscores, hyphens)
    CONSTRAINT chk_role_code_format 
        CHECK (role_code ~ '^[A-Z0-9_-]+$'),
    
    -- Role name length validation
    CONSTRAINT chk_role_name_length 
        CHECK (length(role_name) >= 2 AND length(role_name) <= 100),
    
    -- Role code length validation
    CONSTRAINT chk_role_code_length 
        CHECK (length(role_code) >= 2 AND length(role_code) <= 50),
    
    -- System roles cannot be deactivated
    CONSTRAINT chk_system_role_active 
        CHECK (NOT (is_system_role = true AND is_active = false)),
    
    -- Audit user references (soft constraint - users may be deleted)
    CONSTRAINT user_roles_created_by_fkey 
        FOREIGN KEY (created_by) 
        REFERENCES users (id) 
        ON DELETE SET NULL,
    
    CONSTRAINT user_roles_updated_by_fkey 
        FOREIGN KEY (updated_by) 
        REFERENCES users (id) 
        ON DELETE SET NULL
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Primary lookup index for role code (most common query)
CREATE INDEX IF NOT EXISTS idx_user_roles_code 
    ON public.user_roles 
    USING btree (role_code) 
    TABLESPACE pg_default;

-- Active roles index for permission checking
CREATE INDEX IF NOT EXISTS idx_user_roles_active 
    ON public.user_roles 
    USING btree (is_active, role_code) 
    TABLESPACE pg_default
    WHERE is_active = true;

-- System roles index for administrative queries
CREATE INDEX IF NOT EXISTS idx_user_roles_system 
    ON public.user_roles 
    USING btree (is_system_role, is_active) 
    TABLESPACE pg_default;

-- Role name search index
CREATE INDEX IF NOT EXISTS idx_user_roles_name 
    ON public.user_roles 
    USING btree (role_name) 
    TABLESPACE pg_default;

-- Text search index for description
CREATE INDEX IF NOT EXISTS idx_user_roles_description_search 
    ON public.user_roles 
    USING gin (to_tsvector('english', description)) 
    TABLESPACE pg_default
    WHERE description IS NOT NULL;

-- Audit tracking indexes
CREATE INDEX IF NOT EXISTS idx_user_roles_created_at 
    ON public.user_roles 
    USING btree (created_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_roles_created_by 
    ON public.user_roles 
    USING btree (created_by) 
    TABLESPACE pg_default
    WHERE created_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_roles_updated_by 
    ON public.user_roles 
    USING btree (updated_by) 
    TABLESPACE pg_default
    WHERE updated_by IS NOT NULL;

-- =====================================================
-- Trigger Function for Updated At Timestamp
-- =====================================================

-- Create or replace the update_updated_at_column function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic updated_at timestamp
CREATE TRIGGER update_user_roles_updated_at 
    BEFORE UPDATE ON user_roles 
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Functions for Role Management
-- =====================================================

-- Function to create a new role
CREATE OR REPLACE FUNCTION create_user_role(
    p_role_name VARCHAR(100),
    p_role_code VARCHAR(50),
    p_description TEXT DEFAULT NULL,
    p_is_system_role BOOLEAN DEFAULT false,
    p_created_by UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    role_id UUID;
BEGIN
    -- Validate role code format
    IF p_role_code !~ '^[A-Z0-9_-]+$' THEN
        RAISE EXCEPTION 'Role code must contain only uppercase letters, numbers, underscores, and hyphens';
    END IF;
    
    -- Insert new role
    INSERT INTO public.user_roles (
        role_name, role_code, description, is_system_role, created_by
    ) VALUES (
        p_role_name, p_role_code, p_description, p_is_system_role, p_created_by
    )
    RETURNING id INTO role_id;
    
    RETURN role_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get role by code
CREATE OR REPLACE FUNCTION get_role_by_code(
    p_role_code VARCHAR(50)
)
RETURNS TABLE (
    role_id UUID,
    role_name VARCHAR,
    role_code VARCHAR,
    description TEXT,
    is_system_role BOOLEAN,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ur.id as role_id,
        ur.role_name,
        ur.role_code,
        ur.description,
        ur.is_system_role,
        ur.is_active,
        ur.created_at,
        ur.updated_at
    FROM public.user_roles ur
    WHERE ur.role_code = p_role_code;
END;
$$ LANGUAGE plpgsql;

-- Function to get all active roles
CREATE OR REPLACE FUNCTION get_active_roles()
RETURNS TABLE (
    role_id UUID,
    role_name VARCHAR,
    role_code VARCHAR,
    description TEXT,
    is_system_role BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    user_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ur.id as role_id,
        ur.role_name,
        ur.role_code,
        ur.description,
        ur.is_system_role,
        ur.created_at,
        COALESCE(user_counts.user_count, 0) as user_count
    FROM public.user_roles ur
    LEFT JOIN (
        SELECT 
            role_id,
            COUNT(*) as user_count
        FROM public.user_role_assignments
        WHERE is_active = true
        GROUP BY role_id
    ) user_counts ON ur.id = user_counts.role_id
    WHERE ur.is_active = true
    ORDER BY ur.role_name;
END;
$$ LANGUAGE plpgsql;

-- Function to update role status
CREATE OR REPLACE FUNCTION update_role_status(
    p_role_id UUID,
    p_is_active BOOLEAN,
    p_updated_by UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    is_system BOOLEAN;
BEGIN
    -- Check if role exists and get system role status
    SELECT is_system_role INTO is_system
    FROM public.user_roles
    WHERE id = p_role_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Role not found';
    END IF;
    
    -- Prevent deactivating system roles
    IF is_system = true AND p_is_active = false THEN
        RAISE EXCEPTION 'System roles cannot be deactivated';
    END IF;
    
    -- Update role status
    UPDATE public.user_roles
    SET 
        is_active = p_is_active,
        updated_by = p_updated_by,
        updated_at = now()
    WHERE id = p_role_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Function to search roles
CREATE OR REPLACE FUNCTION search_roles(
    p_search_term TEXT DEFAULT NULL,
    p_include_inactive BOOLEAN DEFAULT false,
    p_system_roles_only BOOLEAN DEFAULT false
)
RETURNS TABLE (
    role_id UUID,
    role_name VARCHAR,
    role_code VARCHAR,
    description TEXT,
    is_system_role BOOLEAN,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    user_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ur.id as role_id,
        ur.role_name,
        ur.role_code,
        ur.description,
        ur.is_system_role,
        ur.is_active,
        ur.created_at,
        COALESCE(user_counts.user_count, 0) as user_count
    FROM public.user_roles ur
    LEFT JOIN (
        SELECT 
            role_id,
            COUNT(*) as user_count
        FROM public.user_role_assignments
        WHERE is_active = true
        GROUP BY role_id
    ) user_counts ON ur.id = user_counts.role_id
    WHERE 
        (p_include_inactive OR ur.is_active = true)
        AND (NOT p_system_roles_only OR ur.is_system_role = true)
        AND (
            p_search_term IS NULL 
            OR ur.role_name ILIKE '%' || p_search_term || '%'
            OR ur.role_code ILIKE '%' || p_search_term || '%'
            OR ur.description ILIKE '%' || p_search_term || '%'
        )
    ORDER BY ur.is_system_role DESC, ur.role_name;
END;
$$ LANGUAGE plpgsql;

-- Function to get role hierarchy and permissions
CREATE OR REPLACE FUNCTION get_role_details(
    p_role_id UUID
)
RETURNS TABLE (
    role_id UUID,
    role_name VARCHAR,
    role_code VARCHAR,
    description TEXT,
    is_system_role BOOLEAN,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    user_count BIGINT,
    permission_count BIGINT,
    creator_name VARCHAR,
    updater_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ur.id as role_id,
        ur.role_name,
        ur.role_code,
        ur.description,
        ur.is_system_role,
        ur.is_active,
        ur.created_at,
        ur.updated_at,
        COALESCE(user_counts.user_count, 0) as user_count,
        COALESCE(perm_counts.permission_count, 0) as permission_count,
        creator.full_name as creator_name,
        updater.full_name as updater_name
    FROM public.user_roles ur
    LEFT JOIN (
        SELECT 
            role_id,
            COUNT(*) as user_count
        FROM public.user_role_assignments
        WHERE is_active = true
        GROUP BY role_id
    ) user_counts ON ur.id = user_counts.role_id
    LEFT JOIN (
        SELECT 
            role_id,
            COUNT(*) as permission_count
        FROM public.role_permissions
        WHERE is_active = true
        GROUP BY role_id
    ) perm_counts ON ur.id = perm_counts.role_id
    LEFT JOIN public.users creator ON ur.created_by = creator.id
    LEFT JOIN public.users updater ON ur.updated_by = updater.id
    WHERE ur.id = p_role_id;
END;
$$ LANGUAGE plpgsql;

-- Function to validate role operations
CREATE OR REPLACE FUNCTION validate_role_operation(
    p_role_id UUID,
    p_operation VARCHAR(20)
)
RETURNS TABLE (
    is_valid BOOLEAN,
    reason TEXT,
    user_count BIGINT
) AS $$
DECLARE
    role_record RECORD;
    assigned_users BIGINT;
BEGIN
    -- Get role information
    SELECT * INTO role_record
    FROM public.user_roles
    WHERE id = p_role_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Role not found', 0::BIGINT;
        RETURN;
    END IF;
    
    -- Get user assignment count
    SELECT COUNT(*) INTO assigned_users
    FROM public.user_role_assignments
    WHERE role_id = p_role_id AND is_active = true;
    
    -- Validate operation
    CASE p_operation
        WHEN 'DELETE' THEN
            IF role_record.is_system_role THEN
                RETURN QUERY SELECT false, 'System roles cannot be deleted', assigned_users;
            ELSIF assigned_users > 0 THEN
                RETURN QUERY SELECT false, 'Role has active user assignments', assigned_users;
            ELSE
                RETURN QUERY SELECT true, 'Role can be deleted', assigned_users;
            END IF;
            
        WHEN 'DEACTIVATE' THEN
            IF role_record.is_system_role THEN
                RETURN QUERY SELECT false, 'System roles cannot be deactivated', assigned_users;
            ELSIF NOT role_record.is_active THEN
                RETURN QUERY SELECT false, 'Role is already inactive', assigned_users;
            ELSE
                RETURN QUERY SELECT true, 'Role can be deactivated', assigned_users;
            END IF;
            
        WHEN 'MODIFY' THEN
            IF role_record.is_system_role THEN
                RETURN QUERY SELECT false, 'System roles have restricted modifications', assigned_users;
            ELSE
                RETURN QUERY SELECT true, 'Role can be modified', assigned_users;
            END IF;
            
        ELSE
            RETURN QUERY SELECT false, 'Unknown operation', assigned_users;
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Triggers for Data Validation and Audit
-- =====================================================

-- Trigger function for role validation
CREATE OR REPLACE FUNCTION trigger_validate_role_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- Prevent modification of system roles (except status by admin)
    IF OLD.is_system_role = true AND TG_OP = 'UPDATE' THEN
        -- Allow only status changes and audit fields for system roles
        IF (OLD.role_name != NEW.role_name OR 
            OLD.role_code != NEW.role_code OR 
            OLD.description IS DISTINCT FROM NEW.description) THEN
            RAISE EXCEPTION 'System role core properties cannot be modified';
        END IF;
    END IF;
    
    -- Ensure role codes are uppercase
    NEW.role_code := UPPER(NEW.role_code);
    
    -- Validate role code format on insert/update
    IF NEW.role_code !~ '^[A-Z0-9_-]+$' THEN
        RAISE EXCEPTION 'Role code must contain only uppercase letters, numbers, underscores, and hyphens';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create validation trigger
CREATE TRIGGER trigger_role_validation
    BEFORE INSERT OR UPDATE ON public.user_roles
    FOR EACH ROW
    EXECUTE FUNCTION trigger_validate_role_changes();

-- =====================================================
-- Views for Role Management
-- =====================================================

-- View for role overview with statistics
CREATE OR REPLACE VIEW role_overview AS
SELECT 
    ur.id,
    ur.role_name,
    ur.role_code,
    ur.description,
    ur.is_system_role,
    ur.is_active,
    ur.created_at,
    ur.updated_at,
    COALESCE(user_stats.active_users, 0) as active_users,
    COALESCE(user_stats.total_users, 0) as total_users,
    COALESCE(perm_stats.permission_count, 0) as permission_count,
    creator.full_name as created_by_name,
    updater.full_name as updated_by_name
FROM public.user_roles ur
LEFT JOIN (
    SELECT 
        role_id,
        COUNT(CASE WHEN is_active = true THEN 1 END) as active_users,
        COUNT(*) as total_users
    FROM public.user_role_assignments
    GROUP BY role_id
) user_stats ON ur.id = user_stats.role_id
LEFT JOIN (
    SELECT 
        role_id,
        COUNT(*) as permission_count
    FROM public.role_permissions
    WHERE is_active = true
    GROUP BY role_id
) perm_stats ON ur.id = perm_stats.role_id
LEFT JOIN public.users creator ON ur.created_by = creator.id
LEFT JOIN public.users updater ON ur.updated_by = updater.id;

-- View for system roles only
CREATE OR REPLACE VIEW system_roles AS
SELECT 
    id,
    role_name,
    role_code,
    description,
    is_active,
    created_at
FROM public.user_roles
WHERE is_system_role = true
ORDER BY role_name;

-- View for active user roles (for permission checking)
CREATE OR REPLACE VIEW active_user_roles AS
SELECT 
    id,
    role_name,
    role_code,
    description
FROM public.user_roles
WHERE is_active = true
ORDER BY role_name;

-- =====================================================
-- Initial System Roles Data
-- =====================================================

-- Function to initialize system roles
CREATE OR REPLACE FUNCTION initialize_system_roles()
RETURNS INTEGER AS $$
DECLARE
    inserted_count INTEGER := 0;
BEGIN
    -- Insert system roles if they don't exist
    INSERT INTO public.user_roles (role_name, role_code, description, is_system_role, is_active)
    SELECT * FROM (VALUES
        ('Master Admin', 'MASTER_ADMIN', 'Full system administrator with all permissions', true, true),
        ('System Admin', 'SYSTEM_ADMIN', 'System administrator with administrative permissions', true, true),
        ('HR Manager', 'HR_MANAGER', 'Human resources manager with HR module access', true, true),
        ('Task Manager', 'TASK_MANAGER', 'Task management supervisor with task oversight', true, true),
        ('Employee', 'EMPLOYEE', 'Standard employee with basic access permissions', true, true),
        ('Guest', 'GUEST', 'Limited access guest user with read-only permissions', true, true),
        ('API User', 'API_USER', 'Service account for API integrations', true, true)
    ) AS roles(role_name, role_code, description, is_system_role, is_active)
    WHERE NOT EXISTS (
        SELECT 1 FROM public.user_roles WHERE role_code = roles.role_code
    );
    
    GET DIAGNOSTICS inserted_count = ROW_COUNT;
    RETURN inserted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.user_roles IS 'Role-based access control (RBAC) system for user authorization - defines roles that can be assigned to users for permission management';

COMMENT ON COLUMN public.user_roles.id IS 'Primary key - unique identifier for each role';
COMMENT ON COLUMN public.user_roles.role_name IS 'Human-readable name of the role (e.g., "System Administrator")';
COMMENT ON COLUMN public.user_roles.role_code IS 'Unique code identifier for the role (e.g., "SYSTEM_ADMIN")';
COMMENT ON COLUMN public.user_roles.description IS 'Detailed description of the role purpose and permissions';
COMMENT ON COLUMN public.user_roles.is_system_role IS 'Flag indicating if this is a system-defined role (cannot be deleted/modified)';
COMMENT ON COLUMN public.user_roles.is_active IS 'Flag indicating if the role is currently active and can be assigned';
COMMENT ON COLUMN public.user_roles.created_at IS 'Timestamp when the role was created';
COMMENT ON COLUMN public.user_roles.updated_at IS 'Timestamp when the role was last updated (auto-updated by trigger)';
COMMENT ON COLUMN public.user_roles.created_by IS 'User who created this role (soft reference)';
COMMENT ON COLUMN public.user_roles.updated_by IS 'User who last updated this role (soft reference)';

-- Index comments
COMMENT ON INDEX idx_user_roles_code IS 'Primary lookup index for role code queries (most common access pattern)';
COMMENT ON INDEX idx_user_roles_active IS 'Performance index for active role filtering in permission checks';
COMMENT ON INDEX idx_user_roles_system IS 'Index for system role administrative queries';

-- Function comments
COMMENT ON FUNCTION create_user_role(VARCHAR, VARCHAR, TEXT, BOOLEAN, UUID) IS 'Creates a new user role with validation and audit tracking';
COMMENT ON FUNCTION get_role_by_code(VARCHAR) IS 'Retrieves role information by role code for permission checking';
COMMENT ON FUNCTION search_roles(TEXT, BOOLEAN, BOOLEAN) IS 'Advanced role search with filtering options for administrative interfaces';
COMMENT ON FUNCTION validate_role_operation(UUID, VARCHAR) IS 'Validates role operations (delete, deactivate, modify) based on business rules';
COMMENT ON FUNCTION initialize_system_roles() IS 'Sets up required system roles for application functionality';

-- Trigger comments
COMMENT ON TRIGGER update_user_roles_updated_at ON public.user_roles IS 'Automatically updates the updated_at timestamp when role data changes';
COMMENT ON TRIGGER trigger_role_validation ON public.user_roles IS 'Validates role data integrity and business rules before data changes';

-- View comments
COMMENT ON VIEW role_overview IS 'Comprehensive role management view with user assignment and permission statistics';
COMMENT ON VIEW system_roles IS 'System-defined roles view for administrative reference';
COMMENT ON VIEW active_user_roles IS 'Active roles view optimized for permission checking and role assignment';