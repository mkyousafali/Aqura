-- Active Warnings View
-- Shows all active employee warnings with detailed information
CREATE OR REPLACE VIEW public.active_warnings_view AS
SELECT 
    ew.*,
    he.employee_name,
    he.employee_code,
    u.username as issued_by_user,
    b.branch_name
FROM public.employee_warnings ew
LEFT JOIN public.hr_employees he ON ew.employee_id = he.id
LEFT JOIN public.users u ON ew.issued_by = u.id
LEFT JOIN public.branches b ON ew.branch_id = b.id
WHERE ew.warning_status = 'active' 
AND ew.is_deleted = false;