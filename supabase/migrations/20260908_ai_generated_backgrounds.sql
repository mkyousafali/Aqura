-- Dedicated library of AI-generated flyer backgrounds (see FlyerTemplateDesigner.svelte's
-- "Generate New Background" flow and its new "Save" / "Get from Library" actions). Kept separate
-- from the `flyer-templates` bucket/table so a generated background can be browsed and reused
-- across templates without needing to be regenerated or re-uploaded.

CREATE TABLE IF NOT EXISTS public.ai_generated_backgrounds (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    image_url text NOT NULL,
    storage_path text NOT NULL,
    offer_description_ar text,
    color_theme text,
    card_count integer,
    canvas_width integer DEFAULT 794,
    canvas_height integer DEFAULT 1123,
    source_template_id uuid REFERENCES public.flyer_templates(id) ON DELETE SET NULL,
    created_by uuid,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_ai_generated_backgrounds_created_at ON public.ai_generated_backgrounds(created_at DESC);

ALTER TABLE public.ai_generated_backgrounds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to ai_generated_backgrounds" ON public.ai_generated_backgrounds;
CREATE POLICY "Allow all access to ai_generated_backgrounds" ON public.ai_generated_backgrounds USING (true) WITH CHECK (true);

GRANT ALL ON public.ai_generated_backgrounds TO authenticated, anon, service_role;

-- Storage for the saved copies (separate from the `flyer-templates` bucket, which holds
-- per-template working images).
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('ai-generated-backgrounds', 'ai-generated-backgrounds', true, 10485760, '{image/jpeg,image/jpg,image/png,image/webp}')
ON CONFLICT (id) DO NOTHING;

COMMENT ON TABLE public.ai_generated_backgrounds IS 'Library of AI-generated flyer background images, saved from FlyerTemplateDesigner''s Generate New Background flow so they can be reused later via Get from Library without regenerating';
