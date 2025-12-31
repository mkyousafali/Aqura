-- Flyer Templates Table Schema
CREATE TABLE IF NOT EXISTS flyer_templates (
  id INTEGER PRIMARY KEY DEFAULT nextval('flyer_templates_id_seq'),
  template_name VARCHAR NOT NULL,
  description TEXT,
  template_layout JSONB NOT NULL,
  dimensions_width INTEGER,
  dimensions_height INTEGER,
  dpi INTEGER NOT NULL DEFAULT 300,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
