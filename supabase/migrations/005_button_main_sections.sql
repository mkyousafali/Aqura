-- Button Main Sections Table Schema
CREATE TABLE IF NOT EXISTS button_main_sections (
  id BIGINT PRIMARY KEY,
  section_name_en VARCHAR NOT NULL,
  section_name_ar VARCHAR NOT NULL,
  section_code VARCHAR NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
