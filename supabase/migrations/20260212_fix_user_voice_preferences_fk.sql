-- Fix user_voice_preferences - remove FK constraint entirely
-- The preference table doesn't need strict referential integrity
ALTER TABLE user_voice_preferences DROP CONSTRAINT IF EXISTS user_voice_preferences_user_id_fkey;
