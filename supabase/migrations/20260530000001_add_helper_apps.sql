BEGIN;

-- ─── Permission check helper function ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.check_helper_apps_permission()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        COALESCE((SELECT is_master_admin FROM public.users WHERE id = auth.uid()), false)
        OR
        EXISTS (
            SELECT 1
            FROM public.sidebar_buttons sb
            JOIN public.button_permissions bp ON bp.button_id = sb.id
            WHERE sb.button_code = 'HELPER_APPS'
              AND bp.user_id = auth.uid()
              AND bp.is_enabled = true
        );
$$;

GRANT EXECUTE ON FUNCTION public.check_helper_apps_permission() TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_helper_apps_permission() TO anon;

-- ─── Helper Apps table ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.helper_apps (
    id          uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    app_name    text        NOT NULL,
    file_name   text        NOT NULL,
    file_path   text        NOT NULL DEFAULT 'pending',
    file_size   bigint,
    file_type   text,
    storage_bucket text     NOT NULL DEFAULT 'helper-apps',
    created_by  uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by  uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.helper_apps ENABLE ROW LEVEL SECURITY;

-- SELECT: any authenticated user may view completed (non-pending) records
CREATE POLICY "helper_apps_select"
ON public.helper_apps
FOR SELECT TO authenticated
USING (file_path <> 'pending');

-- INSERT: users with HELPER_APPS permission
CREATE POLICY "helper_apps_insert"
ON public.helper_apps
FOR INSERT TO authenticated
WITH CHECK (public.check_helper_apps_permission());

-- UPDATE: users with HELPER_APPS permission (includes setting file_path after upload)
CREATE POLICY "helper_apps_update"
ON public.helper_apps
FOR UPDATE TO authenticated
USING (public.check_helper_apps_permission())
WITH CHECK (public.check_helper_apps_permission());

-- DELETE: users with HELPER_APPS permission (for rollback on failed uploads)
CREATE POLICY "helper_apps_delete"
ON public.helper_apps
FOR DELETE TO authenticated
USING (public.check_helper_apps_permission());

GRANT SELECT, INSERT, UPDATE, DELETE ON public.helper_apps TO authenticated;

-- ─── Storage bucket (private) ─────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('helper-apps', 'helper-apps', false, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

-- Storage: SELECT (needed to create signed URLs for download)
CREATE POLICY "helper_apps_storage_select"
ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'helper-apps' AND public.check_helper_apps_permission());

-- Storage: INSERT (upload)
CREATE POLICY "helper_apps_storage_insert"
ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'helper-apps' AND public.check_helper_apps_permission());

-- Storage: UPDATE (replace / upsert)
CREATE POLICY "helper_apps_storage_update"
ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'helper-apps' AND public.check_helper_apps_permission())
WITH CHECK (bucket_id = 'helper-apps' AND public.check_helper_apps_permission());

-- Storage: DELETE (rollback on failed upload)
CREATE POLICY "helper_apps_storage_delete"
ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'helper-apps' AND public.check_helper_apps_permission());

-- ─── Sidebar: ensure CONTROLS → OPERATIONS subsection exists ─────────────────
INSERT INTO public.button_sub_sections (
    main_section_id,
    subsection_code,
    subsection_name_en,
    subsection_name_ar,
    display_order,
    is_active
)
SELECT ms.id, 'OPERATIONS', 'Operations', 'العمليات', 3, true
FROM public.button_main_sections ms
WHERE ms.section_code = 'CONTROLS'
  AND NOT EXISTS (
    SELECT 1 FROM public.button_sub_sections ss
    WHERE ss.main_section_id = ms.id AND ss.subsection_code = 'OPERATIONS'
  );

-- ─── Sidebar: add HELPER_APPS button under CONTROLS → OPERATIONS ─────────────
INSERT INTO public.sidebar_buttons (
    button_name_en,
    button_name_ar,
    button_code,
    main_section_id,
    subsection_id,
    display_order,
    is_active
)
SELECT
    'Helper Apps',
    'التطبيقات المساعدة',
    'HELPER_APPS',
    ms.id,
    ss.id,
    3,
    true
FROM public.button_main_sections ms
JOIN public.button_sub_sections ss
    ON ss.main_section_id = ms.id
    AND ss.subsection_code = 'OPERATIONS'
WHERE ms.section_code = 'CONTROLS'
  AND NOT EXISTS (
    SELECT 1 FROM public.sidebar_buttons b WHERE b.button_code = 'HELPER_APPS'
  );

COMMIT;
