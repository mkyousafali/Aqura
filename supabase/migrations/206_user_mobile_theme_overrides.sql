-- Add color_overrides column to user_mobile_theme_assignments for per-user customization
ALTER TABLE public.user_mobile_theme_assignments
ADD COLUMN color_overrides JSONB DEFAULT NULL;

-- Add comment explaining the column
COMMENT ON COLUMN public.user_mobile_theme_assignments.color_overrides IS
'User-specific color overrides. Merge with theme colors at runtime. Stores only properties that differ from base theme.';

-- Create index for faster queries
CREATE INDEX idx_user_theme_overrides ON public.user_mobile_theme_assignments(user_id) WHERE color_overrides IS NOT NULL;
