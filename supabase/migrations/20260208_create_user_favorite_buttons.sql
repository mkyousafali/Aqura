-- ============================================================
-- Migration: Create user_favorite_buttons table
-- Date: 2026-02-08
-- Description: Stores per-user favorite sidebar button config
-- ============================================================

-- Create the user_favorite_buttons table
CREATE TABLE IF NOT EXISTS public.user_favorite_buttons (
    id TEXT PRIMARY KEY,                          -- e.g. 'fv1', 'fv2', ...
    employee_id TEXT,                             -- optional reference to hr_employee_master (no FK to avoid insert issues)
    user_id UUID NOT NULL,                        -- references auth.users
    favorite_config JSONB NOT NULL DEFAULT '[]'::jsonb,  -- Array of { button_code, button_name_en, icon }
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_user_favorite UNIQUE (user_id)     -- One row per user
);

-- Create index for fast lookups by user_id
CREATE INDEX IF NOT EXISTS idx_user_favorite_buttons_user_id ON public.user_favorite_buttons(user_id);

-- Create index for employee_id lookups
CREATE INDEX IF NOT EXISTS idx_user_favorite_buttons_employee_id ON public.user_favorite_buttons(employee_id);

-- Enable RLS
ALTER TABLE public.user_favorite_buttons ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any
DROP POLICY IF EXISTS "Allow all access to user_favorite_buttons" ON public.user_favorite_buttons;

-- Simple permissive policy for all operations (matching app pattern)
CREATE POLICY "Allow all access to user_favorite_buttons"
    ON public.user_favorite_buttons
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant access to ALL roles (critical - app uses anon role client)
GRANT ALL ON public.user_favorite_buttons TO anon;
GRANT ALL ON public.user_favorite_buttons TO authenticated;
GRANT ALL ON public.user_favorite_buttons TO service_role;
