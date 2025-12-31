-- Shelf Paper Templates Table Schema
CREATE TABLE IF NOT EXISTS shelf_paper_templates (
  id INTEGER PRIMARY KEY DEFAULT nextval('shelf_paper_templates_id_seq'),
  template_name VARCHAR NOT NULL,
  description TEXT,
  template_layout JSONB NOT NULL,
  fields_config JSONB,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
