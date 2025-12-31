-- Variation Audit Log Table Schema
CREATE TABLE IF NOT EXISTS variation_audit_log (
  id INTEGER PRIMARY KEY DEFAULT nextval('variation_audit_log_id_seq'),
  variation_id UUID NOT NULL,
  product_id VARCHAR NOT NULL,
  action VARCHAR NOT NULL,
  changed_by UUID,
  old_value JSONB,
  new_value JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
