-- Sidebar Buttons Table Schema
CREATE TABLE IF NOT EXISTS sidebar_buttons (
  id INTEGER PRIMARY KEY DEFAULT nextval('sidebar_buttons_id_seq'),
  section_id INTEGER NOT NULL,
  button_name VARCHAR NOT NULL,
  button_label VARCHAR NOT NULL,
  button_icon VARCHAR,
  button_color VARCHAR,
  action_type VARCHAR NOT NULL,
  action_target VARCHAR,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  requires_permission VARCHAR,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
