-- User Permissions View
-- Creates a comprehensive view of user permissions by joining users, roles, and permissions

-- First, drop the view if it exists
DROP VIEW IF EXISTS user_permissions_view;

-- Create user_permissions_view
CREATE OR REPLACE VIEW user_permissions_view AS
SELECT 
    u.id as user_id,
    u.username,
    ur.role_name,
    af.function_name,
    af.function_code,
    COALESCE(rp.can_view, false) as can_view,
    COALESCE(rp.can_add, false) as can_add,
    COALESCE(rp.can_edit, false) as can_edit,
    COALESCE(rp.can_delete, false) as can_delete,
    COALESCE(rp.can_export, false) as can_export
FROM users u
LEFT JOIN user_roles ur ON (
    -- Map user role_type to role_code
    (u.role_type = 'Master Admin' AND ur.role_code = 'master_admin') OR
    (u.role_type = 'Admin' AND ur.role_code = 'admin') OR
    (u.role_type = 'Position-based' AND ur.role_code = 'employee')
)
LEFT JOIN role_permissions rp ON ur.id = rp.role_id
LEFT JOIN app_functions af ON rp.function_id = af.id
WHERE u.status = 'active' 
    AND ur.is_active = true 
    AND af.is_active = true
ORDER BY u.username, af.function_code;

-- Grant necessary permissions
GRANT SELECT ON user_permissions_view TO authenticated;
GRANT SELECT ON user_permissions_view TO anon;

-- Create indexes on the underlying tables for better performance
CREATE INDEX IF NOT EXISTS idx_users_role_type ON users(role_type) WHERE role_type IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_roles_code ON user_roles(role_code) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_role_permissions_composite ON role_permissions(role_id, function_id);
CREATE INDEX IF NOT EXISTS idx_app_functions_active ON app_functions(function_code) WHERE is_active = true;