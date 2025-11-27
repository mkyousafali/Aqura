-- Add quick_access_code to user_management_view
-- Drop and recreate the view to change column order
DROP VIEW IF EXISTS user_management_view;

CREATE VIEW user_management_view AS
SELECT 
    u.id,
    u.username,
    u.quick_access_code,
    u.user_type,
    u.status,
    u.role_type,
    u.is_first_login,
    u.last_login_at as last_login,
    u.failed_login_attempts,
    u.created_at,
    u.updated_at,
    u.avatar,
    
    -- Employee details
    e.id as employee_id,
    e.employee_id as employee_code,
    e.name as employee_name,
    e.status as employee_status,
    e.hire_date,
    
    -- Branch details
    b.id as branch_id,
    b.name_en as branch_name,
    b.name_ar as branch_name_ar,
    b.location_en as branch_location_en,
    b.location_ar as branch_location_ar,
    b.is_active as branch_active,
    
    -- Position details
    p.id as position_id,
    p.position_title_en as position_title_en,
    p.position_title_ar as position_title_ar,
    
    -- Department details (through position)
    d.id as department_id,
    d.department_name_en as department_name_en,
    d.department_name_ar as department_name_ar
    
FROM users u
LEFT JOIN hr_employees e ON u.employee_id = e.id
LEFT JOIN branches b ON u.branch_id = b.id
LEFT JOIN hr_positions p ON u.position_id = p.id
LEFT JOIN hr_departments d ON p.department_id = d.id;
