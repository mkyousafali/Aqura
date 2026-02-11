-- Create user_theme_assignments table
-- Maps users to their assigned desktop theme

CREATE TABLE IF NOT EXISTS user_theme_assignments (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  theme_id INTEGER NOT NULL REFERENCES desktop_themes(id) ON DELETE CASCADE,
  assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_theme_assignments_user_id ON user_theme_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_user_theme_assignments_theme_id ON user_theme_assignments(theme_id);

-- Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION update_user_theme_assignments_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_theme_assignments_timestamp_update
BEFORE UPDATE ON user_theme_assignments
FOR EACH ROW
EXECUTE FUNCTION update_user_theme_assignments_timestamp();
