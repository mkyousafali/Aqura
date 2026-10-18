-- Remove only the retired sidebar animation feature.
-- Drop without CASCADE so unexpected dependencies stop the transaction.
BEGIN;

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

DELETE FROM public.button_permissions WHERE button_code = 'SIDEBAR_ANIMATION';

DROP FUNCTION IF EXISTS public.deactivate_sidebar_animation(uuid);
DROP FUNCTION IF EXISTS public.delete_sidebar_animation(uuid);
DROP FUNCTION IF EXISTS public.get_active_sidebar_animation();
DROP FUNCTION IF EXISTS public.insert_sidebar_animation(text, text);
DROP FUNCTION IF EXISTS public.list_sidebar_animations();
DROP FUNCTION IF EXISTS public.set_active_sidebar_animation(uuid);

DROP TABLE IF EXISTS public.sidebar_animations;

DROP POLICY IF EXISTS "Auth users manage sidebar-animations" ON storage.objects;
DROP POLICY IF EXISTS "Public read sidebar-animations" ON storage.objects;

COMMIT;
