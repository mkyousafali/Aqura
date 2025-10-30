-- User Permissions View
-- Shows all permissions for each user
CREATE OR REPLACE VIEW public.user_permissions_view AS
SELECT 
    u.id as user_id,
    u.username,
    ur.role_id,
    r.role_name,
    rp.permission,
    rp.resource
FROM public.users u
JOIN public.user_roles ur ON u.id = ur.user_id
JOIN public.roles r ON ur.role_id = r.id
JOIN public.role_permissions rp ON r.id = rp.role_id
WHERE ur.is_active = true;