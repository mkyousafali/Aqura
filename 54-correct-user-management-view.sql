-- Correct User Management View
-- Based on actual table structure from schema files

-- First, let's drop the problematic view if it exists
DROP VIEW IF EXISTS user_management_view;

-- Create user_management_view with actual column structure
CREATE OR REPLACE VIEW user_management_view AS
SELECT 
    u.id,
    u.username,
    u.user_type,
    u.status,
    u.role_type,
    u.is_first_login,
    u.last_login_at as last_login,
    u.failed_login_attempts,
    u.created_at,
    u.updated_at,
    u.avatar,
    
    -- Employee details (using actual hr_employees columns)
    u.employee_id,
    e.employee_id as employee_code,
    e.name as employee_name,
    e.status as employee_status,
    e.hire_date,
    
    -- Branch details
    u.branch_id,
    b.name_en as branch_name,
    b.name_ar as branch_name_ar,
    b.location_en as branch_location_en,
    b.location_ar as branch_location_ar,
    b.is_active as branch_active,
    
    -- Position details (if position_id exists in users table)
    u.position_id,
    p.position_title_en,
    p.position_title_ar,
    
    -- Department details (through position)
    d.id as department_id,
    d.department_name_en,
    d.department_name_ar
    
FROM users u
LEFT JOIN hr_employees e ON u.employee_id = e.id
LEFT JOIN branches b ON u.branch_id = b.id
LEFT JOIN hr_positions p ON u.position_id = p.id
LEFT JOIN hr_departments d ON p.department_id = d.id
ORDER BY u.username;

-- Grant necessary permissions
GRANT SELECT ON user_management_view TO authenticated;
GRANT SELECT ON user_management_view TO anon;

-- Create indexes on the underlying tables for better performance
CREATE INDEX IF NOT EXISTS idx_users_employee_lookup ON users(employee_id) WHERE employee_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_branch_lookup ON users(branch_id) WHERE branch_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_position_lookup ON users(position_id) WHERE position_id IS NOT NULL;