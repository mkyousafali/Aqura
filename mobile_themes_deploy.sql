-- Create mobile_themes table
CREATE TABLE IF NOT EXISTS public.mobile_themes (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    colors JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Create user_mobile_theme_assignments table
CREATE TABLE IF NOT EXISTS public.user_mobile_theme_assignments (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    theme_id BIGINT NOT NULL REFERENCES public.mobile_themes(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_mobile_themes_is_default ON public.mobile_themes(is_default);
CREATE INDEX IF NOT EXISTS idx_user_mobile_theme_assignments_user_id ON public.user_mobile_theme_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_user_mobile_theme_assignments_theme_id ON public.user_mobile_theme_assignments(theme_id);

-- Enable RLS
ALTER TABLE public.mobile_themes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_mobile_theme_assignments ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "mobile_themes_view" ON public.mobile_themes FOR SELECT USING (TRUE);
CREATE POLICY "mobile_themes_modify" ON public.mobile_themes FOR ALL USING (EXISTS (SELECT 1 FROM auth.users WHERE auth.users.id = auth.uid() AND raw_user_meta_data->>'isMasterAdmin' = 'true'));
CREATE POLICY "user_mobile_theme_assignments_view" ON public.user_mobile_theme_assignments FOR SELECT USING (auth.uid() = user_id OR EXISTS (SELECT 1 FROM auth.users WHERE auth.users.id = auth.uid() AND raw_user_meta_data->>'isMasterAdmin' = 'true'));
CREATE POLICY "user_mobile_theme_assignments_modify" ON public.user_mobile_theme_assignments FOR ALL USING (EXISTS (SELECT 1 FROM auth.users WHERE auth.users.id = auth.uid() AND raw_user_meta_data->>'isMasterAdmin' = 'true'));

-- Insert default theme
INSERT INTO public.mobile_themes (name, description, is_default, colors) VALUES ('Standard Mobile', 'Default mobile interface theme', TRUE, jsonb_build_object('bg_primary', '#f9fafb', 'bg_secondary', '#ffffff', 'text_primary', '#0b1220', 'text_secondary', '#6b7280', 'accent_primary', '#0066b2', 'accent_secondary', '#3b82f6', 'border_color', '#e5e7eb', 'success_color', '#10b981', 'warning_color', '#f59e0b', 'error_color', '#ef4444', 'sidebar_bg', '#ffffff', 'sidebar_text', '#0b1220', 'card_bg', '#ffffff', 'card_border', '#e5e7eb', 'button_primary_bg', '#0066b2', 'button_primary_text', '#ffffff', 'button_secondary_bg', '#e5e7eb', 'button_secondary_text', '#0b1220')) ON CONFLICT (name) DO NOTHING;

-- Grant permissions
GRANT SELECT ON TABLE public.mobile_themes TO authenticated, anon;
GRANT ALL ON TABLE public.mobile_themes TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.user_mobile_theme_assignments TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.mobile_themes_id_seq TO authenticated, anon;
GRANT USAGE, SELECT ON SEQUENCE public.user_mobile_theme_assignments_id_seq TO authenticated;
