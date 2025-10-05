-- Missing Database Views
-- This creates the user_management_view that the frontend expects

-- Drop existing view if it exists
DROP VIEW IF EXISTS public.user_management_view;

-- Create user_management_view that combines user and employee data
CREATE VIEW public.user_management_view AS
SELECT 
    u.id,
    u.username,
    u.email,
    u.role_type,
    u.status,
    u.employee_id,
    u.branch_id,
    u.quick_access_code,
    u.last_login_at,
    u.created_at,
    u.updated_at,
    u.deleted_at,
    -- Employee details
    e.first_name,
    e.last_name,
    e.employee_code,
    e.phone_number,
    e.hire_date,
    e.status as employee_status,
    e.department_id,
    e.position_id,
    -- Department details
    d.name as department_name,
    -- Position details
    p.title as position_title,
    -- Branch details
    b.name as branch_name,
    b.code as branch_code,
    -- Computed fields
    COALESCE(e.first_name || ' ' || e.last_name, e.first_name, u.username) as full_name,
    CASE 
        WHEN u.deleted_at IS NULL AND u.status = 'active' THEN true
        ELSE false
    END as is_active
FROM users u
LEFT JOIN hr_employees e ON u.employee_id = e.id
LEFT JOIN hr_departments d ON e.department_id = d.id
LEFT JOIN hr_positions p ON e.position_id = p.id
LEFT JOIN branches b ON u.branch_id = b.id;

-- Grant permissions on the view
GRANT SELECT ON public.user_management_view TO authenticated;
GRANT SELECT ON public.user_management_view TO anon;

-- Create additional views that might be needed

-- Employee management view
DROP VIEW IF EXISTS public.employee_management_view;
CREATE VIEW public.employee_management_view AS
SELECT 
    e.id,
    e.employee_code,
    e.first_name,
    e.last_name,
    e.first_name || ' ' || COALESCE(e.last_name, '') as full_name,
    e.phone_number,
    e.email as employee_email,
    e.hire_date,
    e.status,
    e.department_id,
    e.position_id,
    e.branch_id,
    e.created_at,
    e.updated_at,
    -- Department info
    d.name as department_name,
    -- Position info
    p.title as position_title,
    p.level_id,
    -- Branch info
    b.name as branch_name,
    b.code as branch_code,
    -- User info (if linked)
    u.id as user_id,
    u.username,
    u.role_type
FROM hr_employees e
LEFT JOIN hr_departments d ON e.department_id = d.id
LEFT JOIN hr_positions p ON e.position_id = p.id
LEFT JOIN branches b ON e.branch_id = b.id
LEFT JOIN users u ON u.employee_id = e.id;

GRANT SELECT ON public.employee_management_view TO authenticated;
GRANT SELECT ON public.employee_management_view TO anon;

-- Test the views
SELECT 'Views created successfully!' as status;

-- Test user_management_view
SELECT 'Testing user_management_view:' as info;
SELECT id, username, email, role_type, full_name, is_active
FROM user_management_view 
WHERE deleted_at IS NULL
LIMIT 5;

-- Test specific user lookup (like the one failing)
SELECT 'Testing specific user lookup:' as info;
SELECT id, username, email, role_type, status, full_name
FROM user_management_view 
WHERE id = 'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b';