-- HR Positions Table Schema
CREATE TABLE IF NOT EXISTS hr_positions (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  position_title_en VARCHAR NOT NULL,
  position_title_ar VARCHAR NOT NULL,
  department_id UUID NOT NULL,
  level_id UUID NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
