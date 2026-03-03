-- Create mobile_themes table
-- Stores named color themes for the mobile interface UI elements

CREATE TABLE IF NOT EXISTS mobile_themes (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255) DEFAULT '',
  is_default BOOLEAN DEFAULT false,
  
  -- Header/Top Bar colors
  header_bg VARCHAR(100) DEFAULT '#0066b2',
  header_text VARCHAR(30) DEFAULT '#FFFFFF',
  header_icon VARCHAR(30) DEFAULT '#FFFFFF',
  header_border VARCHAR(100) DEFAULT 'rgba(255, 255, 255, 0.2)',
  
  -- Navigation/Bottom Bar colors
  navbar_bg VARCHAR(30) DEFAULT '#F9FAFB',
  navbar_border VARCHAR(100) DEFAULT 'rgba(0, 0, 0, 0.1)',
  navbar_btn_active_bg VARCHAR(30) DEFAULT '#0066b2',
  navbar_btn_active_text VARCHAR(30) DEFAULT '#FFFFFF',
  navbar_btn_inactive_bg VARCHAR(30) DEFAULT 'transparent',
  navbar_btn_inactive_text VARCHAR(30) DEFAULT '#6B7280',
  navbar_btn_hover_bg VARCHAR(30) DEFAULT '#E5E7EB',
  
  -- Card colors
  card_bg VARCHAR(30) DEFAULT '#FFFFFF',
  card_text VARCHAR(30) DEFAULT '#1F2937',
  card_border VARCHAR(100) DEFAULT 'rgba(0, 0, 0, 0.1)',
  card_shadow VARCHAR(100) DEFAULT '0 1px 3px rgba(0, 0, 0, 0.1)',
  
  -- Button colors
  button_primary_bg VARCHAR(30) DEFAULT '#0066b2',
  button_primary_text VARCHAR(30) DEFAULT '#FFFFFF',
  button_primary_hover VARCHAR(30) DEFAULT '#004d8c',
  button_secondary_bg VARCHAR(30) DEFAULT '#E5E7EB',
  button_secondary_text VARCHAR(30) DEFAULT '#1F2937',
  button_secondary_hover VARCHAR(30) DEFAULT '#D1D5DB',
  
  -- Input colors
  input_bg VARCHAR(30) DEFAULT '#FFFFFF',
  input_border VARCHAR(100) DEFAULT 'rgba(0, 0, 0, 0.15)',
  input_text VARCHAR(30) DEFAULT '#1F2937',
  input_focus_border VARCHAR(30) DEFAULT '#0066b2',
  input_placeholder VARCHAR(30) DEFAULT '#9CA3AF',
  
  -- Badge/Status colors
  badge_primary_bg VARCHAR(30) DEFAULT '#0066b2',
  badge_primary_text VARCHAR(30) DEFAULT '#FFFFFF',
  badge_success_bg VARCHAR(30) DEFAULT '#10B981',
  badge_success_text VARCHAR(30) DEFAULT '#FFFFFF',
  badge_warning_bg VARCHAR(30) DEFAULT '#F59E0B',
  badge_warning_text VARCHAR(30) DEFAULT '#FFFFFF',
  badge_error_bg VARCHAR(30) DEFAULT '#EF4444',
  badge_error_text VARCHAR(30) DEFAULT '#FFFFFF',
  
  -- Background colors
  bg_primary VARCHAR(30) DEFAULT '#FFFFFF',
  bg_secondary VARCHAR(30) DEFAULT '#F9FAFB',
  bg_tertiary VARCHAR(30) DEFAULT '#F3F4F6',
  
  -- Text colors
  text_primary VARCHAR(30) DEFAULT '#1F2937',
  text_secondary VARCHAR(30) DEFAULT '#6B7280',
  text_tertiary VARCHAR(30) DEFAULT '#9CA3AF',
  
  -- Accent colors
  accent_primary VARCHAR(30) DEFAULT '#0066b2',
  accent_secondary VARCHAR(30) DEFAULT '#1DBC83',
  
  -- Divider
  divider_color VARCHAR(100) DEFAULT 'rgba(0, 0, 0, 0.1)',
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Create user_mobile_theme_assignments table
CREATE TABLE IF NOT EXISTS user_mobile_theme_assignments (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  theme_id INTEGER NOT NULL REFERENCES mobile_themes(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(user_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_mobile_themes_is_default ON mobile_themes(is_default);
CREATE INDEX IF NOT EXISTS idx_user_mobile_theme_assignments_user_id ON user_mobile_theme_assignments(user_id);
CREATE INDEX IF NOT EXISTS idx_user_mobile_theme_assignments_theme_id ON user_mobile_theme_assignments(theme_id);

-- Auto-update timestamp trigger for mobile_themes
CREATE OR REPLACE FUNCTION update_mobile_themes_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER mobile_themes_timestamp_update
BEFORE UPDATE ON mobile_themes
FOR EACH ROW
EXECUTE FUNCTION update_mobile_themes_timestamp();

-- Auto-update timestamp trigger for user_mobile_theme_assignments
CREATE OR REPLACE FUNCTION update_user_mobile_theme_assignments_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER user_mobile_theme_assignments_timestamp_update
BEFORE UPDATE ON user_mobile_theme_assignments
FOR EACH ROW
EXECUTE FUNCTION update_user_mobile_theme_assignments_timestamp();

-- Enable RLS
ALTER TABLE mobile_themes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_mobile_theme_assignments ENABLE ROW LEVEL SECURITY;

-- RLS Policies for mobile_themes (allow viewing all)
CREATE POLICY "Allow all to view mobile_themes"
  ON mobile_themes
  FOR SELECT
  TO authenticated, anon
  USING (true);

CREATE POLICY "Allow insert/update/delete mobile_themes to authenticated"
  ON mobile_themes
  FOR ALL
  TO authenticated
  USING (created_by = auth.uid() OR auth.uid() IN (SELECT id FROM users WHERE is_admin = true));

-- RLS Policies for user_mobile_theme_assignments
CREATE POLICY "Allow users to manage own theme assignments"
  ON user_mobile_theme_assignments
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid());

-- Grants
GRANT SELECT ON mobile_themes TO authenticated, anon;
GRANT ALL ON mobile_themes TO authenticated;
GRANT ALL ON user_mobile_theme_assignments TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE mobile_themes_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE user_mobile_theme_assignments_id_seq TO authenticated;

-- Insert the default "Standard" mobile theme
INSERT INTO mobile_themes (name, description, is_default)
VALUES ('Standard', 'Default Aqura mobile theme with blue header and clean design', true);
