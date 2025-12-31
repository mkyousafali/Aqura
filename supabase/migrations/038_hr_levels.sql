-- HR Levels Table Schema
CREATE TABLE IF NOT EXISTS hr_levels (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  level_name_en VARCHAR NOT NULL,
  level_name_ar VARCHAR NOT NULL,
  level_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
