-- Create mobile_themes table (separate from desktop_themes)
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
    user_id UUID NOT NULL,
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

-- RLS Policy: Allow all access to mobile_themes (permissive, simple pattern)
CREATE POLICY "Allow all access to mobile_themes"
    ON public.mobile_themes
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- RLS Policy: Allow all access to user_mobile_theme_assignments (permissive, simple pattern)
CREATE POLICY "Allow all access to user_mobile_theme_assignments"
    ON public.user_mobile_theme_assignments
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Insert default mobile theme
INSERT INTO public.mobile_themes (name, description, is_default, colors)
VALUES (
    'Standard Mobile',
    'Default mobile interface theme',
    TRUE,
    jsonb_build_object(
        'header_bg', '#0066b2',
        'header_text', '#FFFFFF',
        'header_icon', '#FFFFFF',
        'header_border', 'rgba(255, 255, 255, 0.2)',
        
        'navbar_bg', '#F9FAFB',
        'navbar_border', 'rgba(0, 0, 0, 0.1)',
        'navbar_btn_active_bg', '#0066b2',
        'navbar_btn_active_text', '#FFFFFF',
        'navbar_btn_inactive_bg', 'transparent',
        'navbar_btn_inactive_text', '#6B7280',
        'navbar_btn_hover_bg', '#E5E7EB',
        
        'card_bg', '#FFFFFF',
        'card_text', '#1F2937',
        'card_border', 'rgba(0, 0, 0, 0.1)',
        'card_shadow', '0 1px 3px rgba(0, 0, 0, 0.1)',
        
        'button_primary_bg', '#0066b2',
        'button_primary_text', '#FFFFFF',
        'button_primary_hover', '#004d8c',
        'button_secondary_bg', '#E5E7EB',
        'button_secondary_text', '#1F2937',
        'button_secondary_hover', '#D1D5DB',
        
        'input_bg', '#FFFFFF',
        'input_border', 'rgba(0, 0, 0, 0.15)',
        'input_text', '#1F2937',
        'input_focus_border', '#0066b2',
        'input_placeholder', '#9CA3AF',
        
        'badge_primary_bg', '#0066b2',
        'badge_primary_text', '#FFFFFF',
        'badge_success_bg', '#10B981',
        'badge_success_text', '#FFFFFF',
        'badge_warning_bg', '#F59E0B',
        'badge_warning_text', '#FFFFFF',
        'badge_error_bg', '#EF4444',
        'badge_error_text', '#FFFFFF',
        
        'bg_primary', '#FFFFFF',
        'bg_secondary', '#F9FAFB',
        'bg_tertiary', '#F3F4F6',
        
        'text_primary', '#1F2937',
        'text_secondary', '#6B7280',
        'text_tertiary', '#9CA3AF',
        
        'accent_primary', '#0066b2',
        'accent_secondary', '#1DBC83',
        
        'divider_color', 'rgba(0, 0, 0, 0.1)'
    )
)
ON CONFLICT (name) DO NOTHING;

-- Grant permissions (CRITICAL: must include anon, authenticated, AND service_role)
GRANT ALL ON TABLE public.mobile_themes TO authenticated;
GRANT ALL ON TABLE public.mobile_themes TO service_role;
GRANT ALL ON TABLE public.mobile_themes TO anon;
GRANT ALL ON TABLE public.user_mobile_theme_assignments TO authenticated;
GRANT ALL ON TABLE public.user_mobile_theme_assignments TO service_role;
GRANT ALL ON TABLE public.user_mobile_theme_assignments TO anon;

-- Grant sequence permissions (for auto-increment IDs)
GRANT USAGE, SELECT ON SEQUENCE public.mobile_themes_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.mobile_themes_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.mobile_themes_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.user_mobile_theme_assignments_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.user_mobile_theme_assignments_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.user_mobile_theme_assignments_id_seq TO anon;
