-- Button Sub Sections Table Schema
CREATE TABLE IF NOT EXISTS button_sub_sections (
  id BIGINT PRIMARY KEY,
  main_section_id BIGINT NOT NULL,
  subsection_name_en VARCHAR NOT NULL,
  subsection_name_ar VARCHAR NOT NULL,
  subsection_code VARCHAR NOT NULL,
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
