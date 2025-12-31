-- Audit Logs Table Schema
CREATE TABLE IF NOT EXISTS audit_logs (
  id INTEGER PRIMARY KEY DEFAULT nextval('audit_logs_id_seq'),
  action VARCHAR NOT NULL,
  entity_type VARCHAR NOT NULL,
  entity_id VARCHAR,
  user_id UUID,
  old_value JSONB,
  new_value JSONB,
  ip_address VARCHAR,
  user_agent VARCHAR,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
