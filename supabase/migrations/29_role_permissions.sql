-- Create role_permissions table for managing role-based access control
-- This table defines what permissions each role has for different application functions

-- Create the role_permissions table
CREATE TABLE IF NOT EXISTS public.role_permissions (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    role_id UUID NOT NULL,
    function_id UUID NOT NULL,
    can_view BOOLEAN NULL DEFAULT false,
    can_add BOOLEAN NULL DEFAULT false,
    can_edit BOOLEAN NULL DEFAULT false,
    can_delete BOOLEAN NULL DEFAULT false,
    can_export BOOLEAN NULL DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT role_permissions_pkey PRIMARY KEY (id),
    CONSTRAINT role_permissions_role_id_function_id_key UNIQUE (role_id, function_id),
    CONSTRAINT role_permissions_function_id_fkey 
        FOREIGN KEY (function_id) REFERENCES app_functions (id) ON DELETE CASCADE,
    CONSTRAINT role_permissions_role_id_fkey 
        FOREIGN KEY (role_id) REFERENCES user_roles (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for efficient queries (original indexes)
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id 
ON public.role_permissions USING btree (role_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_role_permissions_function_id 
ON public.role_permissions USING btree (function_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_role_permissions_composite 
ON public.role_permissions USING btree (role_id, function_id) 
TABLESPACE pg_default;

-- Create original trigger
CREATE TRIGGER update_role_permissions_updated_at 
BEFORE UPDATE ON role_permissions 
FOR EACH ROW 
EXECUTE FUNCTION update_updated_at_column();

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_role_permissions_can_view 
ON public.role_permissions (can_view) 
WHERE can_view = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_can_add 
ON public.role_permissions (can_add) 
WHERE can_add = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_can_edit 
ON public.role_permissions (can_edit) 
WHERE can_edit = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_can_delete 
ON public.role_permissions (can_delete) 
WHERE can_delete = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_can_export 
ON public.role_permissions (can_export) 
WHERE can_export = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_created_at 
ON public.role_permissions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_role_permissions_updated_at 
ON public.role_permissions (updated_at DESC);

-- Create composite indexes for permission queries
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_view 
ON public.role_permissions (role_id, can_view) 
WHERE can_view = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_function_permissions 
ON public.role_permissions (function_id, can_view, can_add, can_edit, can_delete, can_export);

-- Create partial index for roles with any permissions
CREATE INDEX IF NOT EXISTS idx_role_permissions_any_permission 
ON public.role_permissions (role_id, function_id) 
WHERE can_view = true OR can_add = true OR can_edit = true OR can_delete = true OR can_export = true;

-- Add additional columns for enhanced functionality
ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS can_approve BOOLEAN DEFAULT false;

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS can_reject BOOLEAN DEFAULT false;

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS can_assign BOOLEAN DEFAULT false;

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS can_monitor BOOLEAN DEFAULT false;

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS can_configure BOOLEAN DEFAULT false;

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS permission_level INTEGER DEFAULT 1;

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS restrictions JSONB DEFAULT '{}';

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS conditions JSONB DEFAULT '{}';

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS granted_by UUID;

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

ALTER TABLE public.role_permissions 
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Add foreign key for granted_by
ALTER TABLE public.role_permissions 
ADD CONSTRAINT role_permissions_granted_by_fkey 
FOREIGN KEY (granted_by) REFERENCES users (id) ON DELETE SET NULL;

-- Add validation constraints
ALTER TABLE public.role_permissions 
ADD CONSTRAINT chk_permission_level_valid 
CHECK (permission_level >= 1 AND permission_level <= 10);

ALTER TABLE public.role_permissions 
ADD CONSTRAINT chk_expiry_after_creation 
CHECK (expires_at IS NULL OR expires_at > created_at);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_role_permissions_can_approve 
ON public.role_permissions (can_approve) 
WHERE can_approve = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_can_assign 
ON public.role_permissions (can_assign) 
WHERE can_assign = true;

CREATE INDEX IF NOT EXISTS idx_role_permissions_permission_level 
ON public.role_permissions (permission_level);

CREATE INDEX IF NOT EXISTS idx_role_permissions_granted_by 
ON public.role_permissions (granted_by);

CREATE INDEX IF NOT EXISTS idx_role_permissions_expires_at 
ON public.role_permissions (expires_at) 
WHERE expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_role_permissions_active 
ON public.role_permissions (is_active, role_id, function_id) 
WHERE is_active = true;

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_role_permissions_restrictions 
ON public.role_permissions USING gin (restrictions);

CREATE INDEX IF NOT EXISTS idx_role_permissions_conditions 
ON public.role_permissions USING gin (conditions);

-- Add table and column comments
COMMENT ON TABLE public.role_permissions IS 'Role-based access control permissions for application functions';
COMMENT ON COLUMN public.role_permissions.id IS 'Unique identifier for the permission record';
COMMENT ON COLUMN public.role_permissions.role_id IS 'Reference to the user role';
COMMENT ON COLUMN public.role_permissions.function_id IS 'Reference to the application function';
COMMENT ON COLUMN public.role_permissions.can_view IS 'Permission to view/read data';
COMMENT ON COLUMN public.role_permissions.can_add IS 'Permission to create new records';
COMMENT ON COLUMN public.role_permissions.can_edit IS 'Permission to modify existing records';
COMMENT ON COLUMN public.role_permissions.can_delete IS 'Permission to delete records';
COMMENT ON COLUMN public.role_permissions.can_export IS 'Permission to export data';
COMMENT ON COLUMN public.role_permissions.can_approve IS 'Permission to approve actions/requests';
COMMENT ON COLUMN public.role_permissions.can_reject IS 'Permission to reject actions/requests';
COMMENT ON COLUMN public.role_permissions.can_assign IS 'Permission to assign tasks/responsibilities';
COMMENT ON COLUMN public.role_permissions.can_monitor IS 'Permission to monitor activities';
COMMENT ON COLUMN public.role_permissions.can_configure IS 'Permission to configure system settings';
COMMENT ON COLUMN public.role_permissions.permission_level IS 'Numeric permission level (1-10)';
COMMENT ON COLUMN public.role_permissions.restrictions IS 'Additional restrictions as JSON';
COMMENT ON COLUMN public.role_permissions.conditions IS 'Conditional permissions as JSON';
COMMENT ON COLUMN public.role_permissions.granted_by IS 'User who granted these permissions';
COMMENT ON COLUMN public.role_permissions.expires_at IS 'When these permissions expire (optional)';
COMMENT ON COLUMN public.role_permissions.is_active IS 'Whether these permissions are currently active';
COMMENT ON COLUMN public.role_permissions.notes IS 'Additional notes about the permissions';
COMMENT ON COLUMN public.role_permissions.created_at IS 'When the permissions were created';
COMMENT ON COLUMN public.role_permissions.updated_at IS 'When the permissions were last updated';

-- Create comprehensive view for permissions with role and function details
CREATE OR REPLACE VIEW role_permissions_detailed AS
SELECT 
    rp.id,
    rp.role_id,
    ur.name as role_name,
    ur.description as role_description,
    rp.function_id,
    af.name as function_name,
    af.description as function_description,
    af.module as function_module,
    rp.can_view,
    rp.can_add,
    rp.can_edit,
    rp.can_delete,
    rp.can_export,
    rp.can_approve,
    rp.can_reject,
    rp.can_assign,
    rp.can_monitor,
    rp.can_configure,
    rp.permission_level,
    rp.restrictions,
    rp.conditions,
    rp.granted_by,
    gb.username as granted_by_username,
    gb.full_name as granted_by_name,
    rp.expires_at,
    rp.is_active,
    rp.notes,
    rp.created_at,
    rp.updated_at,
    CASE 
        WHEN rp.expires_at IS NOT NULL AND rp.expires_at < now() THEN true
        ELSE false
    END as is_expired,
    CASE 
        WHEN rp.can_view OR rp.can_add OR rp.can_edit OR rp.can_delete OR rp.can_export OR 
             rp.can_approve OR rp.can_reject OR rp.can_assign OR rp.can_monitor OR rp.can_configure 
        THEN true
        ELSE false
    END as has_any_permission
FROM role_permissions rp
LEFT JOIN user_roles ur ON rp.role_id = ur.id
LEFT JOIN app_functions af ON rp.function_id = af.id
LEFT JOIN users gb ON rp.granted_by = gb.id
ORDER BY ur.name, af.module, af.name;

-- Create function to check user permissions
CREATE OR REPLACE FUNCTION check_user_permission(
    user_id_param UUID,
    function_name_param VARCHAR,
    permission_type VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    has_permission BOOLEAN := false;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM users u
        JOIN user_roles ur ON u.role_id = ur.id
        JOIN role_permissions rp ON ur.id = rp.role_id
        JOIN app_functions af ON rp.function_id = af.id
        WHERE u.id = user_id_param
          AND af.name = function_name_param
          AND rp.is_active = true
          AND (rp.expires_at IS NULL OR rp.expires_at > now())
          AND CASE permission_type
              WHEN 'view' THEN rp.can_view
              WHEN 'add' THEN rp.can_add
              WHEN 'edit' THEN rp.can_edit
              WHEN 'delete' THEN rp.can_delete
              WHEN 'export' THEN rp.can_export
              WHEN 'approve' THEN rp.can_approve
              WHEN 'reject' THEN rp.can_reject
              WHEN 'assign' THEN rp.can_assign
              WHEN 'monitor' THEN rp.can_monitor
              WHEN 'configure' THEN rp.can_configure
              ELSE false
          END
    ) INTO has_permission;
    
    RETURN has_permission;
END;
$$ LANGUAGE plpgsql;

-- Create function to get user permissions for a function
CREATE OR REPLACE FUNCTION get_user_function_permissions(
    user_id_param UUID,
    function_name_param VARCHAR
)
RETURNS TABLE(
    function_name VARCHAR,
    can_view BOOLEAN,
    can_add BOOLEAN,
    can_edit BOOLEAN,
    can_delete BOOLEAN,
    can_export BOOLEAN,
    can_approve BOOLEAN,
    can_reject BOOLEAN,
    can_assign BOOLEAN,
    can_monitor BOOLEAN,
    can_configure BOOLEAN,
    permission_level INTEGER,
    restrictions JSONB,
    conditions JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        af.name as function_name,
        COALESCE(rp.can_view, false) as can_view,
        COALESCE(rp.can_add, false) as can_add,
        COALESCE(rp.can_edit, false) as can_edit,
        COALESCE(rp.can_delete, false) as can_delete,
        COALESCE(rp.can_export, false) as can_export,
        COALESCE(rp.can_approve, false) as can_approve,
        COALESCE(rp.can_reject, false) as can_reject,
        COALESCE(rp.can_assign, false) as can_assign,
        COALESCE(rp.can_monitor, false) as can_monitor,
        COALESCE(rp.can_configure, false) as can_configure,
        COALESCE(rp.permission_level, 1) as permission_level,
        COALESCE(rp.restrictions, '{}') as restrictions,
        COALESCE(rp.conditions, '{}') as conditions
    FROM users u
    JOIN user_roles ur ON u.role_id = ur.id
    JOIN role_permissions rp ON ur.id = rp.role_id
    JOIN app_functions af ON rp.function_id = af.id
    WHERE u.id = user_id_param
      AND af.name = function_name_param
      AND rp.is_active = true
      AND (rp.expires_at IS NULL OR rp.expires_at > now());
END;
$$ LANGUAGE plpgsql;

-- Create function to grant permissions
CREATE OR REPLACE FUNCTION grant_role_permission(
    role_id_param UUID,
    function_id_param UUID,
    permissions JSONB,
    granted_by_param UUID DEFAULT NULL,
    expires_at_param TIMESTAMPTZ DEFAULT NULL,
    notes_param TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    permission_id UUID;
BEGIN
    INSERT INTO role_permissions (
        role_id,
        function_id,
        can_view,
        can_add,
        can_edit,
        can_delete,
        can_export,
        can_approve,
        can_reject,
        can_assign,
        can_monitor,
        can_configure,
        permission_level,
        restrictions,
        conditions,
        granted_by,
        expires_at,
        notes
    ) VALUES (
        role_id_param,
        function_id_param,
        COALESCE((permissions->>'can_view')::BOOLEAN, false),
        COALESCE((permissions->>'can_add')::BOOLEAN, false),
        COALESCE((permissions->>'can_edit')::BOOLEAN, false),
        COALESCE((permissions->>'can_delete')::BOOLEAN, false),
        COALESCE((permissions->>'can_export')::BOOLEAN, false),
        COALESCE((permissions->>'can_approve')::BOOLEAN, false),
        COALESCE((permissions->>'can_reject')::BOOLEAN, false),
        COALESCE((permissions->>'can_assign')::BOOLEAN, false),
        COALESCE((permissions->>'can_monitor')::BOOLEAN, false),
        COALESCE((permissions->>'can_configure')::BOOLEAN, false),
        COALESCE((permissions->>'permission_level')::INTEGER, 1),
        COALESCE(permissions->'restrictions', '{}'),
        COALESCE(permissions->'conditions', '{}'),
        granted_by_param,
        expires_at_param,
        notes_param
    )
    ON CONFLICT (role_id, function_id) 
    DO UPDATE SET
        can_view = COALESCE((permissions->>'can_view')::BOOLEAN, role_permissions.can_view),
        can_add = COALESCE((permissions->>'can_add')::BOOLEAN, role_permissions.can_add),
        can_edit = COALESCE((permissions->>'can_edit')::BOOLEAN, role_permissions.can_edit),
        can_delete = COALESCE((permissions->>'can_delete')::BOOLEAN, role_permissions.can_delete),
        can_export = COALESCE((permissions->>'can_export')::BOOLEAN, role_permissions.can_export),
        can_approve = COALESCE((permissions->>'can_approve')::BOOLEAN, role_permissions.can_approve),
        can_reject = COALESCE((permissions->>'can_reject')::BOOLEAN, role_permissions.can_reject),
        can_assign = COALESCE((permissions->>'can_assign')::BOOLEAN, role_permissions.can_assign),
        can_monitor = COALESCE((permissions->>'can_monitor')::BOOLEAN, role_permissions.can_monitor),
        can_configure = COALESCE((permissions->>'can_configure')::BOOLEAN, role_permissions.can_configure),
        permission_level = COALESCE((permissions->>'permission_level')::INTEGER, role_permissions.permission_level),
        restrictions = COALESCE(permissions->'restrictions', role_permissions.restrictions),
        conditions = COALESCE(permissions->'conditions', role_permissions.conditions),
        granted_by = COALESCE(granted_by_param, role_permissions.granted_by),
        expires_at = COALESCE(expires_at_param, role_permissions.expires_at),
        notes = COALESCE(notes_param, role_permissions.notes),
        is_active = true,
        updated_at = now()
    RETURNING id INTO permission_id;
    
    RETURN permission_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to revoke permissions
CREATE OR REPLACE FUNCTION revoke_role_permission(
    role_id_param UUID,
    function_id_param UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE role_permissions 
    SET is_active = false,
        updated_at = now()
    WHERE role_id = role_id_param 
      AND function_id = function_id_param;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get role permission summary
CREATE OR REPLACE FUNCTION get_role_permission_summary(role_id_param UUID)
RETURNS TABLE(
    role_name VARCHAR,
    total_functions BIGINT,
    functions_with_view BIGINT,
    functions_with_add BIGINT,
    functions_with_edit BIGINT,
    functions_with_delete BIGINT,
    functions_with_full_access BIGINT,
    expired_permissions BIGINT,
    inactive_permissions BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ur.name as role_name,
        COUNT(*) as total_functions,
        COUNT(*) FILTER (WHERE rp.can_view = true) as functions_with_view,
        COUNT(*) FILTER (WHERE rp.can_add = true) as functions_with_add,
        COUNT(*) FILTER (WHERE rp.can_edit = true) as functions_with_edit,
        COUNT(*) FILTER (WHERE rp.can_delete = true) as functions_with_delete,
        COUNT(*) FILTER (WHERE rp.can_view = true AND rp.can_add = true AND rp.can_edit = true AND rp.can_delete = true) as functions_with_full_access,
        COUNT(*) FILTER (WHERE rp.expires_at IS NOT NULL AND rp.expires_at < now()) as expired_permissions,
        COUNT(*) FILTER (WHERE rp.is_active = false) as inactive_permissions
    FROM user_roles ur
    LEFT JOIN role_permissions rp ON ur.id = rp.role_id
    WHERE ur.id = role_id_param
    GROUP BY ur.id, ur.name;
END;
$$ LANGUAGE plpgsql;

-- Create function to cleanup expired permissions
CREATE OR REPLACE FUNCTION cleanup_expired_permissions()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE role_permissions 
    SET is_active = false,
        updated_at = now()
    WHERE expires_at IS NOT NULL 
      AND expires_at < now() 
      AND is_active = true;
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'role_permissions table created with comprehensive role-based access control features';