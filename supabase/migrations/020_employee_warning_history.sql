-- Employee Warning History Table Schema
CREATE TABLE IF NOT EXISTS employee_warning_history (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  warning_id UUID NOT NULL,
  action_type VARCHAR NOT NULL,
  old_values JSONB,
  new_values JSONB,
  changed_by UUID,
  changed_by_username VARCHAR,
  change_reason TEXT,
  created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ip_address INET,
  user_agent TEXT
);
