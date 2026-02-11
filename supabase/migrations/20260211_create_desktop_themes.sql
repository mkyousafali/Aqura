-- Create desktop_themes table
-- Stores named color themes for the desktop interface UI elements

CREATE TABLE IF NOT EXISTS desktop_themes (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255) DEFAULT '',
  is_default BOOLEAN DEFAULT false,
  
  -- Taskbar colors
  taskbar_bg VARCHAR(100) DEFAULT 'rgba(0, 102, 178, 0.75)',
  taskbar_border VARCHAR(100) DEFAULT 'rgba(255, 255, 255, 0.2)',
  taskbar_btn_active_bg VARCHAR(100) DEFAULT 'linear-gradient(135deg, #4F46E5, #6366F1)',
  taskbar_btn_active_text VARCHAR(30) DEFAULT '#FFFFFF',
  taskbar_btn_inactive_bg VARCHAR(30) DEFAULT 'rgba(255, 255, 255, 0.95)',
  taskbar_btn_inactive_text VARCHAR(30) DEFAULT '#0B1220',
  taskbar_btn_hover_border VARCHAR(30) DEFAULT '#4F46E5',
  taskbar_quick_access_bg VARCHAR(100) DEFAULT 'rgba(255, 255, 255, 0.1)',
  
  -- Sidebar colors
  sidebar_bg VARCHAR(30) DEFAULT '#374151',
  sidebar_text VARCHAR(30) DEFAULT '#e5e7eb',
  sidebar_border VARCHAR(30) DEFAULT '#1f2937',
  sidebar_favorites_bg VARCHAR(30) DEFAULT '#1d2c5e',
  sidebar_favorites_text VARCHAR(30) DEFAULT '#fcd34d',
  
  -- Section & subsection buttons
  section_btn_bg VARCHAR(30) DEFAULT '#1DBC83',
  section_btn_text VARCHAR(30) DEFAULT '#FFFFFF',
  section_btn_hover_bg VARCHAR(30) DEFAULT '#3b82f6',
  section_btn_hover_text VARCHAR(30) DEFAULT '#FFFFFF',
  subsection_btn_bg VARCHAR(30) DEFAULT '#1DBC83',
  subsection_btn_text VARCHAR(30) DEFAULT '#FFFFFF',
  subsection_btn_hover_bg VARCHAR(30) DEFAULT '#3b82f6',
  subsection_btn_hover_text VARCHAR(30) DEFAULT '#FFFFFF',
  
  -- Submenu items
  submenu_item_bg VARCHAR(30) DEFAULT '#FFFFFF',
  submenu_item_text VARCHAR(30) DEFAULT '#f97316',
  submenu_item_hover_bg VARCHAR(30) DEFAULT '#3b82f6',
  submenu_item_hover_text VARCHAR(30) DEFAULT '#FFFFFF',
  
  -- Logo bar
  logo_bar_bg VARCHAR(100) DEFAULT 'linear-gradient(135deg, #15A34A 0%, #22C55E 100%)',
  logo_bar_text VARCHAR(30) DEFAULT '#FFFFFF',
  logo_border VARCHAR(30) DEFAULT '#F59E0B',
  
  -- Window title bars
  window_title_active_bg VARCHAR(30) DEFAULT '#0066b2',
  window_title_active_text VARCHAR(30) DEFAULT '#FFFFFF',
  window_title_inactive_bg VARCHAR(100) DEFAULT 'linear-gradient(135deg, #F9FAFB, #E5E7EB)',
  window_title_inactive_text VARCHAR(30) DEFAULT '#374151',
  window_border_active VARCHAR(30) DEFAULT '#4F46E5',
  
  -- Desktop background
  desktop_bg VARCHAR(30) DEFAULT '#F9FAFB',
  desktop_pattern_opacity VARCHAR(10) DEFAULT '0.4',
  
  -- Interface switch button
  interface_switch_bg VARCHAR(100) DEFAULT 'linear-gradient(145deg, #3b82f6, #2563eb)',
  interface_switch_hover_bg VARCHAR(100) DEFAULT 'linear-gradient(145deg, #2563eb, #1d4ed8)',
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_desktop_themes_is_default ON desktop_themes(is_default);

-- Auto-update timestamp trigger
CREATE OR REPLACE FUNCTION update_desktop_themes_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER desktop_themes_timestamp_update
BEFORE UPDATE ON desktop_themes
FOR EACH ROW
EXECUTE FUNCTION update_desktop_themes_timestamp();

-- Insert the default "Standard" theme with current colors
INSERT INTO desktop_themes (name, description, is_default)
VALUES ('Standard', 'Default Aqura theme with blue taskbar and green accents', true);
