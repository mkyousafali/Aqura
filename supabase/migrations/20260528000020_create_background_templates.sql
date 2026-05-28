-- ============================================================
-- Background Templates: reusable print/letterhead images
-- Bucket: app-templates (PNG, JPG, WEBP – 15 MB max)
-- ============================================================

-- 1. Storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'app-templates',
    'app-templates',
    true,
    15728640,   -- 15 MB
    ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- 2. Storage RLS
CREATE POLICY IF NOT EXISTS "app_templates_select"
    ON storage.objects FOR SELECT
    TO anon, authenticated
    USING (bucket_id = 'app-templates');

CREATE POLICY IF NOT EXISTS "app_templates_insert"
    ON storage.objects FOR INSERT
    TO anon, authenticated
    WITH CHECK (bucket_id = 'app-templates');

CREATE POLICY IF NOT EXISTS "app_templates_update"
    ON storage.objects FOR UPDATE
    TO anon, authenticated
    USING (bucket_id = 'app-templates');

CREATE POLICY IF NOT EXISTS "app_templates_delete"
    ON storage.objects FOR DELETE
    TO anon, authenticated
    USING (bucket_id = 'app-templates');

-- 3. Table
CREATE TABLE IF NOT EXISTS public.background_templates (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        text        NOT NULL,
    name_ar     text,
    storage_path text       NOT NULL,
    bucket      text        NOT NULL DEFAULT 'app-templates',
    mime_type   text,
    file_size   bigint,
    category    text        NOT NULL DEFAULT 'general',
    description text,
    is_active   boolean     NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- 4. RLS
ALTER TABLE public.background_templates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_background_templates" ON public.background_templates;
CREATE POLICY "anon_all_background_templates"
    ON public.background_templates FOR ALL TO anon
    USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "auth_all_background_templates" ON public.background_templates;
CREATE POLICY "auth_all_background_templates"
    ON public.background_templates FOR ALL TO authenticated
    USING (true) WITH CHECK (true);

-- 5. Grants
GRANT ALL ON public.background_templates TO anon;
GRANT ALL ON public.background_templates TO authenticated;
GRANT ALL ON public.background_templates TO service_role;

-- 6. Updated-at trigger
CREATE OR REPLACE FUNCTION public.set_background_templates_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS trg_background_templates_updated_at ON public.background_templates;
CREATE TRIGGER trg_background_templates_updated_at
    BEFORE UPDATE ON public.background_templates
    FOR EACH ROW EXECUTE FUNCTION public.set_background_templates_updated_at();
