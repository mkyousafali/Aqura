-- =====================================================
-- Table: role_permissions
-- Description: Role-based access control (RBAC) permissions mapping
-- This table defines granular permissions for each role-function combination
-- =====================================================

-- Create role_permissions table
CREATE TABLE public.role_permissions (
    -- Primary key with UUID generation using extensions
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    
    -- Foreign keys to roles and functions
    role_id UUID NOT NULL,
    function_id UUID NOT NULL,
    
    -- Granular permission flags for CRUD operations
    can_view BOOLEAN NULL DEFAULT false,
    can_add BOOLEAN NULL DEFAULT false,
    can_edit BOOLEAN NULL DEFAULT false,
    can_delete BOOLEAN NULL DEFAULT false,
    can_export BOOLEAN NULL DEFAULT false,
    
    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    -- Primary key constraint
    CONSTRAINT role_permissions_pkey PRIMARY KEY (id),
    
    -- Unique constraint to prevent duplicate role-function combinations
    CONSTRAINT role_permissions_role_id_function_id_key UNIQUE (role_id, function_id),
    
    -- Foreign key to user_roles table with CASCADE delete
    CONSTRAINT role_permissions_role_id_fkey 
        FOREIGN KEY (role_id) 
        REFERENCES user_roles (id) 
        ON DELETE CASCADE,
    
    -- Foreign key to app_functions table with CASCADE delete
    CONSTRAINT role_permissions_function_id_fkey 
        FOREIGN KEY (function_id) 
        REFERENCES app_functions (id) 
        ON DELETE CASCADE
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Primary lookup indexes for role and function queries
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id 
    ON public.role_permissions 
    USING btree (role_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_role_permissions_function_id 
    ON public.role_permissions 
    USING btree (function_id) 
    TABLESPACE pg_default;

-- Composite index for role-function lookups (most common query pattern)
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_function 
    ON public.role_permissions 
    USING btree (role_id, function_id) 
    TABLESPACE pg_default;

-- Indexes for permission-based queries
CREATE INDEX IF NOT EXISTS idx_role_permissions_can_view 
    ON public.role_permissions 
    USING btree (role_id, can_view) 
    TABLESPACE pg_default
    WHERE can_view = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_can_add 
    ON public.role_permissions 
    USING btree (role_id, can_add) 
    TABLESPACE pg_default
    WHERE can_add = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_can_edit 
    ON public.role_permissions 
    USING btree (role_id, can_edit) 
    TABLESPACE pg_default
    WHERE can_edit = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_can_delete 
    ON public.role_permissions 
    USING btree (role_id, can_delete) 
    TABLESPACE pg_default
    WHERE can_delete = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_can_export 
    ON public.role_permissions 
    USING btree (role_id, can_export) 
    TABLESPACE pg_default
    WHERE can_export = true;

-- Composite index for admin dashboard permission overview
CREATE INDEX IF NOT EXISTS idx_role_permissions_overview 
    ON public.role_permissions 
    USING btree (role_id, function_id, can_view, can_add, can_edit, can_delete) 
    TABLESPACE pg_default;

-- Temporal index for audit purposes
CREATE INDEX IF NOT EXISTS idx_role_permissions_created_at 
    ON public.role_permissions 
    USING btree (created_at DESC) 
    TABLESPACE pg_default;

-- =====================================================
-- Triggers for Automatic Updates
-- =====================================================

-- Create trigger for automatic timestamp updates
CREATE TRIGGER update_role_permissions_updated_at 
    BEFORE UPDATE ON role_permissions 
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Functions for Permission Management
-- =====================================================

-- Function to grant permission to a role for a specific function
CREATE OR REPLACE FUNCTION grant_role_permission(
    p_role_id UUID,
    p_function_id UUID,
    p_can_view BOOLEAN DEFAULT false,
    p_can_add BOOLEAN DEFAULT false,
    p_can_edit BOOLEAN DEFAULT false,
    p_can_delete BOOLEAN DEFAULT false,
    p_can_export BOOLEAN DEFAULT false
)
RETURNS UUID AS $$
DECLARE
    permission_id UUID;
BEGIN
    INSERT INTO public.role_permissions (
        role_id, function_id, can_view, can_add, can_edit, can_delete, can_export
    ) VALUES (
        p_role_id, p_function_id, p_can_view, p_can_add, p_can_edit, p_can_delete, p_can_export
    )
    ON CONFLICT (role_id, function_id) 
    DO UPDATE SET
        can_view = EXCLUDED.can_view,
        can_add = EXCLUDED.can_add,
        can_edit = EXCLUDED.can_edit,
        can_delete = EXCLUDED.can_delete,
        can_export = EXCLUDED.can_export,
        updated_at = now()
    RETURNING id INTO permission_id;
    
    RETURN permission_id;
END;
$$ LANGUAGE plpgsql;

-- Function to revoke all permissions for a role-function combination
CREATE OR REPLACE FUNCTION revoke_role_permission(
    p_role_id UUID,
    p_function_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.role_permissions 
    SET can_view = false,
        can_add = false,
        can_edit = false,
        can_delete = false,
        can_export = false,
        updated_at = now()
    WHERE role_id = p_role_id 
      AND function_id = p_function_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to check if role has specific permission
CREATE OR REPLACE FUNCTION check_role_permission(
    p_role_id UUID,
    p_function_id UUID,
    p_permission_type TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    has_permission BOOLEAN := false;
BEGIN
    CASE p_permission_type
        WHEN 'view' THEN
            SELECT can_view INTO has_permission 
            FROM public.role_permissions 
            WHERE role_id = p_role_id AND function_id = p_function_id;
        WHEN 'add' THEN
            SELECT can_add INTO has_permission 
            FROM public.role_permissions 
            WHERE role_id = p_role_id AND function_id = p_function_id;
        WHEN 'edit' THEN
            SELECT can_edit INTO has_permission 
            FROM public.role_permissions 
            WHERE role_id = p_role_id AND function_id = p_function_id;
        WHEN 'delete' THEN
            SELECT can_delete INTO has_permission 
            FROM public.role_permissions 
            WHERE role_id = p_role_id AND function_id = p_function_id;
        WHEN 'export' THEN
            SELECT can_export INTO has_permission 
            FROM public.role_permissions 
            WHERE role_id = p_role_id AND function_id = p_function_id;
    END CASE;
    
    RETURN COALESCE(has_permission, false);
END;
$$ LANGUAGE plpgsql;

-- Function to get all permissions for a role
CREATE OR REPLACE FUNCTION get_role_permissions(p_role_id UUID)
RETURNS TABLE (
    function_name VARCHAR,
    function_code VARCHAR,
    can_view BOOLEAN,
    can_add BOOLEAN,
    can_edit BOOLEAN,
    can_delete BOOLEAN,
    can_export BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        af.name::VARCHAR as function_name,
        af.function_code::VARCHAR as function_code,
        rp.can_view,
        rp.can_add,
        rp.can_edit,
        rp.can_delete,
        rp.can_export
    FROM public.role_permissions rp
    JOIN public.app_functions af ON rp.function_id = af.id
    WHERE rp.role_id = p_role_id
    ORDER BY af.name;
END;
$$ LANGUAGE plpgsql;

-- Function to copy permissions from one role to another
CREATE OR REPLACE FUNCTION copy_role_permissions(
    p_source_role_id UUID,
    p_target_role_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    copied_count INTEGER := 0;
BEGIN
    INSERT INTO public.role_permissions (
        role_id, function_id, can_view, can_add, can_edit, can_delete, can_export
    )
    SELECT 
        p_target_role_id,
        function_id,
        can_view,
        can_add,
        can_edit,
        can_delete,
        can_export
    FROM public.role_permissions
    WHERE role_id = p_source_role_id
    ON CONFLICT (role_id, function_id) DO NOTHING;
    
    GET DIAGNOSTICS copied_count = ROW_COUNT;
    RETURN copied_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Views for Common Permission Queries
-- =====================================================

-- View for role permission summary
CREATE OR REPLACE VIEW role_permissions_summary AS
SELECT 
    ur.id as role_id,
    ur.name as role_name,
    af.id as function_id,
    af.name as function_name,
    af.function_code,
    COALESCE(rp.can_view, false) as can_view,
    COALESCE(rp.can_add, false) as can_add,
    COALESCE(rp.can_edit, false) as can_edit,
    COALESCE(rp.can_delete, false) as can_delete,
    COALESCE(rp.can_export, false) as can_export,
    rp.created_at as permission_created_at,
    rp.updated_at as permission_updated_at
FROM public.user_roles ur
CROSS JOIN public.app_functions af
LEFT JOIN public.role_permissions rp ON ur.id = rp.role_id AND af.id = rp.function_id
ORDER BY ur.name, af.name;

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.role_permissions IS 'Role-based access control (RBAC) permissions mapping for granular function-level access control';

COMMENT ON COLUMN public.role_permissions.id IS 'Primary key - unique identifier for each role-permission mapping';
COMMENT ON COLUMN public.role_permissions.role_id IS 'Foreign key to user_roles table - which role this permission applies to';
COMMENT ON COLUMN public.role_permissions.function_id IS 'Foreign key to app_functions table - which function this permission controls';
COMMENT ON COLUMN public.role_permissions.can_view IS 'Permission flag for read/view operations on the function';
COMMENT ON COLUMN public.role_permissions.can_add IS 'Permission flag for create/add operations on the function';
COMMENT ON COLUMN public.role_permissions.can_edit IS 'Permission flag for update/edit operations on the function';
COMMENT ON COLUMN public.role_permissions.can_delete IS 'Permission flag for delete operations on the function';
COMMENT ON COLUMN public.role_permissions.can_export IS 'Permission flag for export operations on the function';
COMMENT ON COLUMN public.role_permissions.created_at IS 'Timestamp when the permission mapping was created';
COMMENT ON COLUMN public.role_permissions.updated_at IS 'Timestamp when the permission mapping was last updated (auto-updated)';

-- Index comments
COMMENT ON INDEX idx_role_permissions_role_id IS 'Performance index for role-based permission queries';
COMMENT ON INDEX idx_role_permissions_function_id IS 'Performance index for function-based permission queries';
COMMENT ON INDEX idx_role_permissions_role_function IS 'Composite index for role-function permission lookups (primary access pattern)';
COMMENT ON INDEX idx_role_permissions_overview IS 'Composite index for admin dashboard permission overview queries';

-- Function comments
COMMENT ON FUNCTION grant_role_permission(UUID, UUID, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN, BOOLEAN) IS 'Grants or updates permissions for a role-function combination with upsert logic';
COMMENT ON FUNCTION revoke_role_permission(UUID, UUID) IS 'Revokes all permissions for a specific role-function combination';
COMMENT ON FUNCTION check_role_permission(UUID, UUID, TEXT) IS 'Checks if a role has a specific permission for a function';
COMMENT ON FUNCTION get_role_permissions(UUID) IS 'Returns all permissions for a specific role with function details';
COMMENT ON FUNCTION copy_role_permissions(UUID, UUID) IS 'Copies all permissions from source role to target role';

-- View comments
COMMENT ON VIEW role_permissions_summary IS 'Comprehensive view showing all role-function combinations with permission status';