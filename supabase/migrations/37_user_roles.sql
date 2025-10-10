-- Create user_roles table for role-based access control system
-- This table defines user roles with hierarchical permissions and system management

-- Create the user_roles table
CREATE TABLE IF NOT EXISTS public.user_roles (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    role_name CHARACTER VARYING(100) NOT NULL,
    role_code CHARACTER VARYING(50) NOT NULL,
    description TEXT NULL,
    is_system_role BOOLEAN NULL DEFAULT false,
    is_active BOOLEAN NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    created_by UUID NULL,
    updated_by UUID NULL,
    
    CONSTRAINT user_roles_pkey PRIMARY KEY (id),
    CONSTRAINT user_roles_role_code_key UNIQUE (role_code),
    CONSTRAINT user_roles_role_name_key UNIQUE (role_name)
) TABLESPACE pg_default;

-- Create original index for active roles
CREATE INDEX IF NOT EXISTS idx_user_roles_code 
ON public.user_roles USING btree (role_code) 
TABLESPACE pg_default
WHERE (is_active = true);

-- Add foreign key constraints for created_by and updated_by
ALTER TABLE public.user_roles 
ADD CONSTRAINT user_roles_created_by_fkey 
FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE public.user_roles 
ADD CONSTRAINT user_roles_updated_by_fkey 
FOREIGN KEY (updated_by) REFERENCES users (id) ON DELETE SET NULL;

-- Add additional columns for enhanced functionality
ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS role_level INTEGER DEFAULT 1;

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS parent_role_id UUID;

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS role_permissions JSONB DEFAULT '{}';

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS role_restrictions JSONB DEFAULT '{}';

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS max_users INTEGER;

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS auto_assign_conditions JSONB DEFAULT '{}';

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS role_metadata JSONB DEFAULT '{}';

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS expiration_policy JSONB DEFAULT '{}';

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS role_priority INTEGER DEFAULT 1;

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS is_default_role BOOLEAN DEFAULT false;

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS role_category VARCHAR(50) DEFAULT 'standard';

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS access_level VARCHAR(20) DEFAULT 'basic';

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS role_scope VARCHAR(50) DEFAULT 'global';

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.user_roles 
ADD COLUMN IF NOT EXISTS deleted_by UUID;

-- Add foreign key for parent role hierarchy
ALTER TABLE public.user_roles 
ADD CONSTRAINT user_roles_parent_role_fkey 
FOREIGN KEY (parent_role_id) REFERENCES user_roles (id) ON DELETE SET NULL;

ALTER TABLE public.user_roles 
ADD CONSTRAINT user_roles_deleted_by_fkey 
FOREIGN KEY (deleted_by) REFERENCES users (id) ON DELETE SET NULL;

-- Add validation constraints
ALTER TABLE public.user_roles 
ADD CONSTRAINT chk_role_name_not_empty 
CHECK (TRIM(role_name) != '');

ALTER TABLE public.user_roles 
ADD CONSTRAINT chk_role_code_format 
CHECK (role_code ~ '^[A-Z0-9_]+$');

ALTER TABLE public.user_roles 
ADD CONSTRAINT chk_role_level_positive 
CHECK (role_level > 0 AND role_level <= 100);

ALTER TABLE public.user_roles 
ADD CONSTRAINT chk_max_users_positive 
CHECK (max_users IS NULL OR max_users > 0);

ALTER TABLE public.user_roles 
ADD CONSTRAINT chk_role_priority_valid 
CHECK (role_priority >= 1 AND role_priority <= 1000);

ALTER TABLE public.user_roles 
ADD CONSTRAINT chk_role_category_valid 
CHECK (role_category IN ('system', 'administrative', 'standard', 'guest', 'service', 'temporary'));

ALTER TABLE public.user_roles 
ADD CONSTRAINT chk_access_level_valid 
CHECK (access_level IN ('minimal', 'basic', 'standard', 'elevated', 'administrative', 'system'));

ALTER TABLE public.user_roles 
ADD CONSTRAINT chk_role_scope_valid 
CHECK (role_scope IN ('global', 'organization', 'department', 'team', 'personal'));

ALTER TABLE public.user_roles 
ADD CONSTRAINT chk_no_self_parent 
CHECK (parent_role_id != id);

ALTER TABLE public.user_roles 
ADD CONSTRAINT chk_only_one_default_role 
EXCLUDE (is_default_role WITH =) WHERE (is_default_role = true AND is_active = true);

-- Create additional indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_user_roles_name 
ON public.user_roles (role_name);

CREATE INDEX IF NOT EXISTS idx_user_roles_system_role 
ON public.user_roles (is_system_role) 
WHERE is_system_role = true;

CREATE INDEX IF NOT EXISTS idx_user_roles_active 
ON public.user_roles (is_active);

CREATE INDEX IF NOT EXISTS idx_user_roles_created_by 
ON public.user_roles (created_by);

CREATE INDEX IF NOT EXISTS idx_user_roles_updated_by 
ON public.user_roles (updated_by);

CREATE INDEX IF NOT EXISTS idx_user_roles_parent 
ON public.user_roles (parent_role_id);

CREATE INDEX IF NOT EXISTS idx_user_roles_level 
ON public.user_roles (role_level);

CREATE INDEX IF NOT EXISTS idx_user_roles_priority 
ON public.user_roles (role_priority DESC);

CREATE INDEX IF NOT EXISTS idx_user_roles_category 
ON public.user_roles (role_category);

CREATE INDEX IF NOT EXISTS idx_user_roles_access_level 
ON public.user_roles (access_level);

CREATE INDEX IF NOT EXISTS idx_user_roles_scope 
ON public.user_roles (role_scope);

CREATE INDEX IF NOT EXISTS idx_user_roles_default 
ON public.user_roles (is_default_role) 
WHERE is_default_role = true AND is_active = true;

CREATE INDEX IF NOT EXISTS idx_user_roles_deleted_at 
ON public.user_roles (deleted_at) 
WHERE deleted_at IS NOT NULL;

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_user_roles_permissions 
ON public.user_roles USING gin (role_permissions);

CREATE INDEX IF NOT EXISTS idx_user_roles_restrictions 
ON public.user_roles USING gin (role_restrictions);

CREATE INDEX IF NOT EXISTS idx_user_roles_auto_assign 
ON public.user_roles USING gin (auto_assign_conditions);

CREATE INDEX IF NOT EXISTS idx_user_roles_metadata 
ON public.user_roles USING gin (role_metadata);

CREATE INDEX IF NOT EXISTS idx_user_roles_expiration 
ON public.user_roles USING gin (expiration_policy);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_user_roles_active_level 
ON public.user_roles (is_active, role_level DESC);

CREATE INDEX IF NOT EXISTS idx_user_roles_category_priority 
ON public.user_roles (role_category, role_priority DESC);

CREATE INDEX IF NOT EXISTS idx_user_roles_scope_level 
ON public.user_roles (role_scope, role_level DESC);

-- Add table and column comments
COMMENT ON TABLE public.user_roles IS 'User roles definition for role-based access control with hierarchical permissions';
COMMENT ON COLUMN public.user_roles.id IS 'Unique identifier for the role';
COMMENT ON COLUMN public.user_roles.role_name IS 'Human-readable name of the role';
COMMENT ON COLUMN public.user_roles.role_code IS 'Unique code identifier for the role';
COMMENT ON COLUMN public.user_roles.description IS 'Detailed description of the role and its purpose';
COMMENT ON COLUMN public.user_roles.is_system_role IS 'Whether this is a system-defined role that cannot be deleted';
COMMENT ON COLUMN public.user_roles.is_active IS 'Whether the role is currently active and can be assigned';
COMMENT ON COLUMN public.user_roles.role_level IS 'Hierarchical level of the role (1-100, higher = more permissions)';
COMMENT ON COLUMN public.user_roles.parent_role_id IS 'Parent role for inheritance of permissions';
COMMENT ON COLUMN public.user_roles.role_permissions IS 'JSON object defining specific permissions for this role';
COMMENT ON COLUMN public.user_roles.role_restrictions IS 'JSON object defining restrictions and limitations';
COMMENT ON COLUMN public.user_roles.max_users IS 'Maximum number of users that can have this role';
COMMENT ON COLUMN public.user_roles.auto_assign_conditions IS 'Conditions for automatic role assignment';
COMMENT ON COLUMN public.user_roles.role_metadata IS 'Additional metadata about the role';
COMMENT ON COLUMN public.user_roles.expiration_policy IS 'Policy for role expiration and renewal';
COMMENT ON COLUMN public.user_roles.role_priority IS 'Priority level for role conflicts (1-1000)';
COMMENT ON COLUMN public.user_roles.is_default_role IS 'Whether this is the default role for new users';
COMMENT ON COLUMN public.user_roles.role_category IS 'Category classification of the role';
COMMENT ON COLUMN public.user_roles.access_level IS 'General access level provided by this role';
COMMENT ON COLUMN public.user_roles.role_scope IS 'Scope of the role (global, organization, etc.)';
COMMENT ON COLUMN public.user_roles.created_by IS 'User who created this role';
COMMENT ON COLUMN public.user_roles.updated_by IS 'User who last updated this role';
COMMENT ON COLUMN public.user_roles.deleted_at IS 'Soft delete timestamp';
COMMENT ON COLUMN public.user_roles.deleted_by IS 'User who deleted this role';

-- Create the update trigger (assuming update_updated_at_column function exists)
CREATE TRIGGER update_user_roles_updated_at 
BEFORE UPDATE ON user_roles 
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- Create view for active roles with hierarchy
CREATE OR REPLACE VIEW active_user_roles AS
SELECT 
    ur.id,
    ur.role_name,
    ur.role_code,
    ur.description,
    ur.is_system_role,
    ur.role_level,
    ur.parent_role_id,
    pr.role_name as parent_role_name,
    ur.role_permissions,
    ur.role_restrictions,
    ur.max_users,
    ur.role_priority,
    ur.role_category,
    ur.access_level,
    ur.role_scope,
    ur.created_at,
    ur.updated_at,
    c.username as created_by_username,
    u.username as updated_by_username,
    (SELECT COUNT(*) FROM user_role_assignments ura WHERE ura.role_id = ur.id AND ura.is_active = true) as current_user_count
FROM user_roles ur
LEFT JOIN user_roles pr ON ur.parent_role_id = pr.id
LEFT JOIN users c ON ur.created_by = c.id
LEFT JOIN users u ON ur.updated_by = u.id
WHERE ur.is_active = true AND ur.deleted_at IS NULL
ORDER BY ur.role_priority DESC, ur.role_level DESC;

-- Create function to create a new role
CREATE OR REPLACE FUNCTION create_user_role(
    role_name_param VARCHAR,
    role_code_param VARCHAR,
    description_param TEXT DEFAULT NULL,
    role_level_param INTEGER DEFAULT 1,
    parent_role_id_param UUID DEFAULT NULL,
    permissions_param JSONB DEFAULT '{}',
    restrictions_param JSONB DEFAULT '{}',
    role_category_param VARCHAR DEFAULT 'standard',
    access_level_param VARCHAR DEFAULT 'basic',
    role_scope_param VARCHAR DEFAULT 'global',
    max_users_param INTEGER DEFAULT NULL,
    created_by_param UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    role_id UUID;
    parent_level INTEGER;
BEGIN
    -- Validate parent role level hierarchy
    IF parent_role_id_param IS NOT NULL THEN
        SELECT role_level INTO parent_level 
        FROM user_roles 
        WHERE id = parent_role_id_param AND is_active = true;
        
        IF parent_level IS NULL THEN
            RAISE EXCEPTION 'Parent role not found or inactive';
        END IF;
        
        IF role_level_param >= parent_level THEN
            RAISE EXCEPTION 'Child role level must be lower than parent role level';
        END IF;
    END IF;
    
    -- Insert new role
    INSERT INTO user_roles (
        role_name,
        role_code,
        description,
        role_level,
        parent_role_id,
        role_permissions,
        role_restrictions,
        role_category,
        access_level,
        role_scope,
        max_users,
        created_by
    ) VALUES (
        role_name_param,
        UPPER(role_code_param),
        description_param,
        role_level_param,
        parent_role_id_param,
        permissions_param,
        restrictions_param,
        role_category_param,
        access_level_param,
        role_scope_param,
        max_users_param,
        created_by_param
    ) RETURNING id INTO role_id;
    
    RETURN role_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to get role hierarchy
CREATE OR REPLACE FUNCTION get_role_hierarchy(
    role_id_param UUID,
    include_permissions BOOLEAN DEFAULT false
)
RETURNS TABLE(
    id UUID,
    role_name VARCHAR,
    role_code VARCHAR,
    role_level INTEGER,
    hierarchy_path TEXT,
    depth INTEGER,
    permissions JSONB
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE role_hierarchy AS (
        -- Base case: start with the specified role
        SELECT 
            ur.id,
            ur.role_name,
            ur.role_code,
            ur.role_level,
            ur.role_name::TEXT as hierarchy_path,
            0 as depth,
            CASE WHEN include_permissions THEN ur.role_permissions ELSE '{}'::JSONB END as permissions
        FROM user_roles ur
        WHERE ur.id = role_id_param
        
        UNION ALL
        
        -- Recursive case: get parent roles
        SELECT 
            ur.id,
            ur.role_name,
            ur.role_code,
            ur.role_level,
            (ur.role_name || ' > ' || rh.hierarchy_path)::TEXT,
            rh.depth + 1,
            CASE WHEN include_permissions THEN ur.role_permissions ELSE '{}'::JSONB END
        FROM user_roles ur
        INNER JOIN role_hierarchy rh ON ur.id = rh.id
        INNER JOIN user_roles child ON child.parent_role_id = ur.id
        WHERE child.id = rh.id AND rh.depth < 10 -- Prevent infinite recursion
    )
    SELECT * FROM role_hierarchy ORDER BY depth DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to get effective permissions for a role
CREATE OR REPLACE FUNCTION get_effective_role_permissions(
    role_id_param UUID
)
RETURNS JSONB AS $$
DECLARE
    effective_permissions JSONB := '{}';
    role_record RECORD;
BEGIN
    -- Get all roles in hierarchy (from root to current role)
    FOR role_record IN
        WITH RECURSIVE role_hierarchy AS (
            SELECT id, parent_role_id, role_permissions, 0 as depth
            FROM user_roles
            WHERE id = role_id_param
            
            UNION ALL
            
            SELECT ur.id, ur.parent_role_id, ur.role_permissions, rh.depth + 1
            FROM user_roles ur
            INNER JOIN role_hierarchy rh ON ur.id = rh.parent_role_id
            WHERE rh.depth < 10
        )
        SELECT role_permissions FROM role_hierarchy ORDER BY depth DESC
    LOOP
        -- Merge permissions (child overrides parent)
        effective_permissions := effective_permissions || role_record.role_permissions;
    END LOOP;
    
    RETURN effective_permissions;
END;
$$ LANGUAGE plpgsql;

-- Create function to validate role assignment capacity
CREATE OR REPLACE FUNCTION validate_role_assignment_capacity(
    role_id_param UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    max_users_allowed INTEGER;
    current_users INTEGER;
BEGIN
    SELECT max_users INTO max_users_allowed
    FROM user_roles 
    WHERE id = role_id_param AND is_active = true;
    
    -- If no limit is set, allow assignment
    IF max_users_allowed IS NULL THEN
        RETURN true;
    END IF;
    
    SELECT COUNT(*) INTO current_users
    FROM user_role_assignments
    WHERE role_id = role_id_param AND is_active = true;
    
    RETURN current_users < max_users_allowed;
END;
$$ LANGUAGE plpgsql;

-- Create function to get role statistics
CREATE OR REPLACE FUNCTION get_role_statistics()
RETURNS TABLE(
    total_roles BIGINT,
    active_roles BIGINT,
    system_roles BIGINT,
    roles_by_category JSONB,
    roles_by_access_level JSONB,
    avg_role_level DECIMAL,
    roles_with_users BIGINT,
    unused_roles BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_roles,
        COUNT(*) FILTER (WHERE is_active = true AND deleted_at IS NULL) as active_roles,
        COUNT(*) FILTER (WHERE is_system_role = true) as system_roles,
        jsonb_object_agg(role_category, category_count) as roles_by_category,
        jsonb_object_agg(access_level, access_count) as roles_by_access_level,
        AVG(role_level) as avg_role_level,
        COUNT(DISTINCT ur.id) FILTER (WHERE ura.role_id IS NOT NULL) as roles_with_users,
        COUNT(*) FILTER (WHERE is_active = true AND ura.role_id IS NULL) as unused_roles
    FROM user_roles ur
    LEFT JOIN user_role_assignments ura ON ur.id = ura.role_id AND ura.is_active = true
    LEFT JOIN (
        SELECT role_category, COUNT(*) as category_count
        FROM user_roles
        WHERE is_active = true AND deleted_at IS NULL
        GROUP BY role_category
    ) cat_stats ON true
    LEFT JOIN (
        SELECT access_level, COUNT(*) as access_count
        FROM user_roles
        WHERE is_active = true AND deleted_at IS NULL
        GROUP BY access_level
    ) acc_stats ON true
    WHERE ur.deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql;

-- Create function to soft delete role
CREATE OR REPLACE FUNCTION soft_delete_role(
    role_id_param UUID,
    deleted_by_param UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    role_exists BOOLEAN;
    is_system BOOLEAN;
    has_users BOOLEAN;
BEGIN
    -- Check if role exists and is not already deleted
    SELECT EXISTS (
        SELECT 1 FROM user_roles 
        WHERE id = role_id_param AND deleted_at IS NULL
    ) INTO role_exists;
    
    IF NOT role_exists THEN
        RAISE EXCEPTION 'Role not found or already deleted';
    END IF;
    
    -- Check if it's a system role
    SELECT is_system_role INTO is_system
    FROM user_roles
    WHERE id = role_id_param;
    
    IF is_system THEN
        RAISE EXCEPTION 'Cannot delete system roles';
    END IF;
    
    -- Check if role has active users
    SELECT EXISTS (
        SELECT 1 FROM user_role_assignments 
        WHERE role_id = role_id_param AND is_active = true
    ) INTO has_users;
    
    IF has_users THEN
        RAISE EXCEPTION 'Cannot delete role with active user assignments';
    END IF;
    
    -- Perform soft delete
    UPDATE user_roles 
    SET 
        deleted_at = now(),
        deleted_by = deleted_by_param,
        is_active = false,
        updated_at = now(),
        updated_by = deleted_by_param
    WHERE id = role_id_param;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- Insert default system roles
INSERT INTO user_roles (role_name, role_code, description, is_system_role, role_level, role_category, access_level, role_permissions)
VALUES 
    ('Super Administrator', 'SUPER_ADMIN', 'Full system access with all permissions', true, 100, 'system', 'system', '{"all": true}'),
    ('Administrator', 'ADMIN', 'Administrative access with user and system management', true, 90, 'administrative', 'administrative', '{"user_management": true, "system_config": true}'),
    ('Manager', 'MANAGER', 'Management level access with team oversight', true, 70, 'standard', 'elevated', '{"team_management": true, "reporting": true}'),
    ('User', 'USER', 'Standard user access', true, 50, 'standard', 'standard', '{"basic_access": true}'),
    ('Guest', 'GUEST', 'Limited guest access', true, 10, 'guest', 'minimal', '{"read_only": true}')
ON CONFLICT (role_code) DO NOTHING;

-- Set the default role
UPDATE user_roles SET is_default_role = true WHERE role_code = 'USER' AND NOT EXISTS (
    SELECT 1 FROM user_roles WHERE is_default_role = true AND is_active = true
);

RAISE NOTICE 'user_roles table created with comprehensive role management and hierarchy features';