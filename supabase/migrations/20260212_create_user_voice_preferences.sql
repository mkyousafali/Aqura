-- ============================================
-- User Voice Preferences Table
-- Stores TTS voice selection per user per locale
-- ============================================

CREATE TABLE IF NOT EXISTS user_voice_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    locale TEXT NOT NULL CHECK (locale IN ('en', 'ar')),
    voice_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, locale)
);

-- Enable RLS
ALTER TABLE user_voice_preferences ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to user_voice_preferences" ON user_voice_preferences;

-- Simple permissive policy for all operations (matching app pattern)
CREATE POLICY "Allow all access to user_voice_preferences"
    ON user_voice_preferences
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant access to ALL roles (critical - app uses anon role client)
GRANT ALL ON user_voice_preferences TO anon;
GRANT ALL ON user_voice_preferences TO authenticated;
GRANT ALL ON user_voice_preferences TO service_role;

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_user_voice_preferences_user_id ON user_voice_preferences(user_id);
