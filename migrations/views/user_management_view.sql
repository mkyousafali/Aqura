-- User Management View
-- Combines user data with employee information
CREATE OR REPLACE VIEW public.user_management_view AS
SELECT 
    u.id as user_id,
    u.username,
    u.email,
    u.is_active,
    u.created_at as user_created_at,
    he.id as employee_id,
    he.employee_name,
    he.employee_code,
    hd.department_name,
    hp.position_title,
    b.branch_name
FROM public.users u
LEFT JOIN public.hr_employees he ON u.employee_id = he.id
LEFT JOIN public.hr_departments hd ON he.department_id = hd.id
LEFT JOIN public.hr_positions hp ON he.position_id = hp.id
LEFT JOIN public.branches b ON he.branch_id = b.id;