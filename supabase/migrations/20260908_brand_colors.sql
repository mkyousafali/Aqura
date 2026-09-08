-- Company brand-color palette, managed from Branding > Brand Colors. Used as branding context
-- when AI generates flyer templates/backgrounds (see FlyerTemplateDesigner.svelte's "Generate New
-- Background" flow and /api/generate-flyer-background).

CREATE TABLE IF NOT EXISTS public.brand_colors (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    hex_code text NOT NULL UNIQUE CHECK (hex_code ~* '^#[0-9A-F]{6}$'),
    label text,
    sort_order integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_brand_colors_sort_order ON public.brand_colors(sort_order, created_at);

ALTER TABLE public.brand_colors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to brand_colors" ON public.brand_colors;
CREATE POLICY "Allow all access to brand_colors" ON public.brand_colors USING (true) WITH CHECK (true);

GRANT ALL ON public.brand_colors TO authenticated, anon, service_role;

COMMENT ON TABLE public.brand_colors IS 'Company brand-color palette used across the app and passed as branding context to AI flyer/template generation';

-- Seed the two colors from the brand's official Pantone reference sheet.
INSERT INTO public.brand_colors (hex_code, label, sort_order)
VALUES
    ('#F08300', 'PANTONE P 24-8 C', 0),
    ('#13A538', 'PANTONE P 148-8 C', 1)
ON CONFLICT (hex_code) DO NOTHING;
