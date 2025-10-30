-- Position Roles View
-- Shows positions with their associated roles
CREATE OR REPLACE VIEW public.position_roles_view AS
SELECT 
    hp.id as position_id,
    hp.position_title,
    hp.department_id,
    hd.department_name,
    ur.role_id,
    r.role_name
FROM public.hr_positions hp
LEFT JOIN public.hr_departments hd ON hp.department_id = hd.id
LEFT JOIN public.user_roles ur ON hp.id = ur.position_id
LEFT JOIN public.roles r ON ur.role_id = r.id;