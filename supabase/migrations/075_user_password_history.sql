-- User Password History Table Schema
CREATE TABLE IF NOT EXISTS user_password_history (
  id INTEGER PRIMARY KEY DEFAULT nextval('user_password_history_id_seq'),
  user_id UUID NOT NULL,
  password_hash VARCHAR NOT NULL,
  changed_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  changed_by UUID,
  change_reason VARCHAR,
  is_current BOOLEAN NOT NULL DEFAULT false
);
