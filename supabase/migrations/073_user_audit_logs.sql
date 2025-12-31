-- User Audit Logs Table Schema
CREATE TABLE IF NOT EXISTS user_audit_logs (
  id INTEGER PRIMARY KEY DEFAULT nextval('user_audit_logs_id_seq'),
  user_id UUID NOT NULL,
  action VARCHAR NOT NULL,
  action_details JSONB,
  changed_fields JSONB,
  ip_address VARCHAR,
  user_agent VARCHAR,
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
