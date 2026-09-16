SELECT 'user', u.id::text, u.username, u.status, u.is_master_admin::text, u.is_admin::text
FROM public.users u
WHERE lower(u.username)=lower('yousafali');

SELECT 'permission', bp.user_id::text, bp.button_code, bp.is_enabled::text
FROM public.button_permissions bp
JOIN public.users u ON u.id=bp.user_id
WHERE lower(u.username)=lower('yousafali')
  AND bp.button_code IN ('DEFAULT_POSITIONS','APP_PERMISSIONS')
ORDER BY bp.button_code;

SELECT 'auth_user', a.id::text, a.email
FROM auth.users a
WHERE lower(a.email)=lower('yousafali@aqura.local');
