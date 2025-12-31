-- Order Audit Logs Table Schema
CREATE TABLE IF NOT EXISTS order_audit_logs (
  id INTEGER PRIMARY KEY DEFAULT nextval('order_audit_logs_id_seq'),
  order_id INTEGER NOT NULL,
  action VARCHAR NOT NULL,
  changed_by UUID,
  old_value JSONB,
  new_value JSONB,
  reason VARCHAR,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
