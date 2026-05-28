BEGIN;

-- Remove permissions that reference users that no longer exist.
DELETE FROM public.button_permissions bp
WHERE NOT EXISTS (
  SELECT 1
  FROM public.users u
  WHERE u.id = bp.user_id
);

-- Remove permissions that reference buttons that no longer exist.
DELETE FROM public.button_permissions bp
WHERE NOT EXISTS (
  SELECT 1
  FROM public.sidebar_buttons sb
  WHERE sb.id = bp.button_id
);

COMMIT;
