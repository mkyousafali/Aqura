-- Active Fines View
-- Shows all active fines from warnings
CREATE OR REPLACE VIEW public.active_fines_view AS
SELECT 
    ew.*,
    he.employee_name,
    he.employee_code
FROM public.employee_warnings ew
LEFT JOIN public.hr_employees he ON ew.employee_id = he.id
WHERE ew.has_fine = true 
AND ew.fine_status != 'paid'
AND ew.warning_status = 'active'
AND ew.is_deleted = false;