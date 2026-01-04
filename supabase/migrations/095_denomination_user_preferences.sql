-- Denomination User Preferences Table Schema
-- Stores user preferences for the Denomination feature including default branch selection

CREATE TABLE IF NOT EXISTS denomination_user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  default_branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_denomination_user_preferences_user_id 
  ON denomination_user_preferences(user_id);

-- Enable Row Level Security
ALTER TABLE denomination_user_preferences ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own denomination preferences" ON denomination_user_preferences;
DROP POLICY IF EXISTS "Users can insert own denomination preferences" ON denomination_user_preferences;
DROP POLICY IF EXISTS "Users can update own denomination preferences" ON denomination_user_preferences;
DROP POLICY IF EXISTS "Users can delete own denomination preferences" ON denomination_user_preferences;
DROP POLICY IF EXISTS "Allow all access to denomination preferences" ON denomination_user_preferences;

-- Simple permissive policy for authenticated users (matches other tables in this app)
CREATE POLICY "Allow all access to denomination preferences"
  ON denomination_user_preferences
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to authenticated users
GRANT ALL ON denomination_user_preferences TO authenticated;
GRANT ALL ON denomination_user_preferences TO service_role;
GRANT ALL ON denomination_user_preferences TO anon;

-- Comment on table
COMMENT ON TABLE denomination_user_preferences IS 'Stores user preferences for the Denomination feature';
COMMENT ON COLUMN denomination_user_preferences.user_id IS 'Reference to the user';
COMMENT ON COLUMN denomination_user_preferences.default_branch_id IS 'Default branch selected by the user for denomination';
