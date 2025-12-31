-- Receiving Task Templates Table Schema
CREATE TABLE IF NOT EXISTS receiving_task_templates (
  id INTEGER PRIMARY KEY DEFAULT nextval('receiving_task_templates_id_seq'),
  template_name VARCHAR NOT NULL,
  description TEXT,
  task_items JSONB NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
