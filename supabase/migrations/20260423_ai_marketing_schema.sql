-- ============================================================
-- AI Marketing Module — Complete Schema Migration
-- Spec: "Do not delete/AI Marketing Feature – Final Specification Document.md"
-- ============================================================

BEGIN;

-- =================================================================
-- 1. SIDEBAR BUTTON REGISTRATION (Promo > Manage > AI Marketing)
-- =================================================================
INSERT INTO public.sidebar_buttons
    (main_section_id, subsection_id, button_name_en, button_name_ar, button_code, icon, display_order, is_active)
VALUES
    (14, 51, 'AI Marketing', 'التسويق بالذكاء الاصطناعي', 'AI_MARKETING', '🤖', 100, true)
ON CONFLICT (main_section_id, subsection_id, button_code) DO NOTHING;

-- =================================================================
-- 2. STORAGE BUCKET (for generated videos/posters thumbnails + downloads)
-- =================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'ai-marketing-files',
    'ai-marketing-files',
    false,
    524288000, -- 500 MB max per file
    ARRAY['image/png','image/jpeg','image/webp','video/mp4','video/webm','audio/mpeg','audio/wav','audio/mp3']
)
ON CONFLICT (id) DO NOTHING;

-- =================================================================
-- 3. GLOBAL SETTINGS (single row keyed by id=1)
-- =================================================================
CREATE TABLE IF NOT EXISTS public.ai_marketing_settings (
    id                       smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    -- Google API
    google_api_key           text,
    google_project_id        text,
    google_location          text DEFAULT 'europe-west4',
    -- Generation defaults
    auto_retry               boolean DEFAULT true,
    speed_mode_default       text DEFAULT 'quality' CHECK (speed_mode_default IN ('fast','quality')),
    default_duration_seconds integer DEFAULT 15,
    default_platform         text DEFAULT 'instagram',
    default_language         text DEFAULT 'ar',
    -- AI agent
    base_instructions        text DEFAULT '',
    max_clarification_qs     integer DEFAULT 10,
    -- Audit
    updated_by               uuid,
    updated_at               timestamptz DEFAULT now()
);

INSERT INTO public.ai_marketing_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- =================================================================
-- 4. BRAND LIBRARIES
-- =================================================================
CREATE TABLE IF NOT EXISTS public.ai_brand_libraries (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name              text NOT NULL,
    description       text,
    -- Default assets
    logo_url          text,
    primary_color     text,
    secondary_color   text,
    accent_color      text,
    extra_colors      jsonb DEFAULT '[]'::jsonb,
    -- Brand voice / rules
    brand_tone        text,
    marketing_style   text,
    rules             jsonb DEFAULT '{}'::jsonb,
    -- Lifecycle
    is_default        boolean DEFAULT false,
    is_archived       boolean DEFAULT false,
    created_by        uuid,
    created_at        timestamptz DEFAULT now(),
    updated_at        timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_brand_libraries_active ON public.ai_brand_libraries(is_archived);
CREATE INDEX IF NOT EXISTS idx_ai_brand_libraries_default ON public.ai_brand_libraries(is_default) WHERE is_default = true;

-- =================================================================
-- 5. BRAND CHARACTERS (multiple per library — dad, mom, boy, etc.)
-- =================================================================
CREATE TABLE IF NOT EXISTS public.ai_brand_characters (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    brand_id        bigint NOT NULL REFERENCES public.ai_brand_libraries(id) ON DELETE CASCADE,
    name            text NOT NULL,           -- e.g. "Dad", "Mom", "Layla"
    role            text,                    -- e.g. "father","mother","boy","girl","infant","grandfather","grandmother","custom"
    image_url       text,                    -- reference photo for AI
    description     text,                    -- physical traits, personality
    voice_id        text,                    -- Google TTS voice name (optional)
    display_order   integer DEFAULT 0,
    created_at      timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_brand_characters_brand ON public.ai_brand_characters(brand_id);

-- =================================================================
-- 6. PER-USER PREFERENCES (default brand, favorites)
-- =================================================================
CREATE TABLE IF NOT EXISTS public.ai_marketing_user_prefs (
    user_id            uuid PRIMARY KEY,
    default_brand_id   bigint REFERENCES public.ai_brand_libraries(id) ON DELETE SET NULL,
    favorite_brand_ids bigint[] DEFAULT '{}',
    updated_at         timestamptz DEFAULT now()
);

-- =================================================================
-- 7. MUSIC LIBRARY
-- =================================================================
CREATE TABLE IF NOT EXISTS public.ai_music_library (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         text NOT NULL,
    file_url     text NOT NULL,           -- storage path
    duration_s   integer,
    mood         text,                    -- happy, energetic, calm, dramatic
    tags         text[] DEFAULT '{}',
    uploaded_by  uuid,
    created_at   timestamptz DEFAULT now()
);

-- =================================================================
-- 8. MARKETING FILES (saved generations)
-- =================================================================
CREATE TABLE IF NOT EXISTS public.ai_marketing_files (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            text NOT NULL,
    file_type       text NOT NULL CHECK (file_type IN ('video','poster','branding_video','branding_poster')),
    -- File storage (per spec: store binary IN DB; storage_path is optional fallback)
    file_data       bytea,
    storage_path    text,                  -- alternative: path in ai-marketing-files bucket
    thumbnail_path  text,                  -- thumbnail in ai-marketing-files bucket
    mime_type       text,
    file_size_bytes bigint,
    -- Source / context
    brand_id        bigint REFERENCES public.ai_brand_libraries(id) ON DELETE SET NULL,
    platform        text,                  -- instagram, whatsapp, tiktok, snapchat, facebook
    aspect_ratio    text,                  -- vertical, square, landscape
    duration_s      integer,
    language        text,
    -- Pricing
    price_before    numeric,
    price_offer     numeric,
    -- AI inputs
    prompt          text,
    additional_requirements text,
    speed_mode      text,
    font_choice     text,
    music_id        bigint REFERENCES public.ai_music_library(id) ON DELETE SET NULL,
    music_mode      text CHECK (music_mode IN ('user','ai','none')),
    -- Edit history (jsonb array of { ts, user_id, change, prompt })
    edit_history    jsonb DEFAULT '[]'::jsonb,
    -- Folders
    folder          text DEFAULT '/',
    -- Audit
    created_by      uuid,
    created_at      timestamptz DEFAULT now(),
    updated_at      timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_marketing_files_type     ON public.ai_marketing_files(file_type);
CREATE INDEX IF NOT EXISTS idx_ai_marketing_files_brand    ON public.ai_marketing_files(brand_id);
CREATE INDEX IF NOT EXISTS idx_ai_marketing_files_platform ON public.ai_marketing_files(platform);
CREATE INDEX IF NOT EXISTS idx_ai_marketing_files_lang     ON public.ai_marketing_files(language);
CREATE INDEX IF NOT EXISTS idx_ai_marketing_files_created  ON public.ai_marketing_files(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_marketing_files_folder   ON public.ai_marketing_files(folder);

-- =================================================================
-- 9. FILE -> PRODUCTS junction (max 3 products per spec)
-- =================================================================
CREATE TABLE IF NOT EXISTS public.ai_marketing_file_products (
    file_id     bigint NOT NULL REFERENCES public.ai_marketing_files(id) ON DELETE CASCADE,
    product_id  varchar NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    position    integer NOT NULL DEFAULT 0,
    PRIMARY KEY (file_id, product_id)
);
CREATE INDEX IF NOT EXISTS idx_ai_marketing_fp_product ON public.ai_marketing_file_products(product_id);

-- =================================================================
-- 10. VERSION HISTORY (keep old versions of edits)
-- =================================================================
CREATE TABLE IF NOT EXISTS public.ai_marketing_versions (
    id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    file_id        bigint NOT NULL REFERENCES public.ai_marketing_files(id) ON DELETE CASCADE,
    version_no     integer NOT NULL,
    file_data      bytea,
    storage_path   text,
    thumbnail_path text,
    prompt         text,
    edit_note      text,
    created_by     uuid,
    created_at     timestamptz DEFAULT now(),
    UNIQUE (file_id, version_no)
);
CREATE INDEX IF NOT EXISTS idx_ai_marketing_versions_file ON public.ai_marketing_versions(file_id, version_no DESC);

-- =================================================================
-- 11. GENERATION QUEUE (per-user, 1 active job at a time globally)
-- =================================================================
CREATE TABLE IF NOT EXISTS public.ai_generation_queue (
    id                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    job_type           text NOT NULL CHECK (job_type IN ('video','poster','branding_video','branding_poster')),
    status             text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','running','paused','completed','failed','cancelled')),
    priority           integer DEFAULT 0,                  -- user-controlled within their own jobs
    -- Inputs
    brand_id           bigint REFERENCES public.ai_brand_libraries(id) ON DELETE SET NULL,
    product_ids        varchar[] DEFAULT '{}',
    platform           text,
    aspect_ratio       text,
    duration_s         integer,
    language           text,
    speed_mode         text,
    prompt             text,
    additional_inputs  jsonb DEFAULT '{}'::jsonb,
    clarifications     jsonb DEFAULT '[]'::jsonb,         -- [{ q, a, asked_at }]
    -- Output
    result_file_id     bigint REFERENCES public.ai_marketing_files(id) ON DELETE SET NULL,
    error_message      text,
    progress_pct       integer DEFAULT 0,
    -- Audit
    created_by         uuid,
    created_at         timestamptz DEFAULT now(),
    started_at         timestamptz,
    finished_at        timestamptz,
    updated_at         timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_queue_status   ON public.ai_generation_queue(status);
CREATE INDEX IF NOT EXISTS idx_ai_queue_user     ON public.ai_generation_queue(created_by, status);
CREATE INDEX IF NOT EXISTS idx_ai_queue_priority ON public.ai_generation_queue(priority DESC, created_at);

-- =================================================================
-- 12. NOTIFICATIONS (toast + history)
-- =================================================================
CREATE TABLE IF NOT EXISTS public.ai_notifications (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     uuid,
    type        text NOT NULL,             -- started, progress, completed, failed, saved
    title       text NOT NULL,
    message     text,
    job_id      bigint REFERENCES public.ai_generation_queue(id) ON DELETE CASCADE,
    file_id     bigint REFERENCES public.ai_marketing_files(id) ON DELETE CASCADE,
    is_read     boolean DEFAULT false,
    created_at  timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_notifications_user ON public.ai_notifications(user_id, is_read, created_at DESC);

-- =================================================================
-- 13. updated_at TRIGGERS
-- =================================================================
CREATE OR REPLACE FUNCTION public._ai_marketing_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'ai_marketing_settings','ai_brand_libraries','ai_marketing_user_prefs',
    'ai_marketing_files','ai_generation_queue'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trg_%I_touch ON public.%I;', t, t);
    EXECUTE format('CREATE TRIGGER trg_%I_touch BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public._ai_marketing_touch_updated_at();', t, t);
  END LOOP;
END $$;

-- =================================================================
-- 14. ENFORCE: only one default brand library at a time
-- =================================================================
CREATE OR REPLACE FUNCTION public._ai_brand_enforce_single_default()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.is_default = true THEN
    UPDATE public.ai_brand_libraries SET is_default = false WHERE id <> NEW.id AND is_default = true;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_ai_brand_single_default ON public.ai_brand_libraries;
CREATE TRIGGER trg_ai_brand_single_default
  BEFORE INSERT OR UPDATE OF is_default ON public.ai_brand_libraries
  FOR EACH ROW WHEN (NEW.is_default = true)
  EXECUTE FUNCTION public._ai_brand_enforce_single_default();

-- =================================================================
-- 15. RLS — open to authenticated (matches existing project convention)
-- =================================================================
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'ai_marketing_settings','ai_brand_libraries','ai_brand_characters',
    'ai_marketing_user_prefs','ai_music_library','ai_marketing_files',
    'ai_marketing_file_products','ai_marketing_versions',
    'ai_generation_queue','ai_notifications'
  ] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', t);
    EXECUTE format('DROP POLICY IF EXISTS "allow_select" ON public.%I;', t);
    EXECUTE format('DROP POLICY IF EXISTS "allow_insert" ON public.%I;', t);
    EXECUTE format('DROP POLICY IF EXISTS "allow_update" ON public.%I;', t);
    EXECUTE format('DROP POLICY IF EXISTS "allow_delete" ON public.%I;', t);
    EXECUTE format('CREATE POLICY "allow_select" ON public.%I FOR SELECT USING (true);', t);
    EXECUTE format('CREATE POLICY "allow_insert" ON public.%I FOR INSERT WITH CHECK (true);', t);
    EXECUTE format('CREATE POLICY "allow_update" ON public.%I FOR UPDATE USING (true) WITH CHECK (true);', t);
    EXECUTE format('CREATE POLICY "allow_delete" ON public.%I FOR DELETE USING (true);', t);
  END LOOP;
END $$;

-- =================================================================
-- 16. GRANTS
-- =================================================================
GRANT SELECT, INSERT, UPDATE, DELETE ON
  public.ai_marketing_settings,
  public.ai_brand_libraries,
  public.ai_brand_characters,
  public.ai_marketing_user_prefs,
  public.ai_music_library,
  public.ai_marketing_files,
  public.ai_marketing_file_products,
  public.ai_marketing_versions,
  public.ai_generation_queue,
  public.ai_notifications
TO authenticated, anon, service_role;

GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon, service_role;

COMMIT;

-- ============================================================
-- Verification
-- ============================================================
SELECT 'Tables created:' AS info;
SELECT table_name FROM information_schema.tables
WHERE table_schema='public' AND table_name LIKE 'ai_%' ORDER BY table_name;

SELECT 'Sidebar button registered:' AS info;
SELECT id, button_code, button_name_en, main_section_id, subsection_id
FROM public.sidebar_buttons WHERE button_code = 'AI_MARKETING';

SELECT 'Storage bucket:' AS info;
SELECT id, public, file_size_limit FROM storage.buckets WHERE id = 'ai-marketing-files';
