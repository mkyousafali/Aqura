-- User Device Sessions Table Schema
CREATE TABLE IF NOT EXISTS user_device_sessions (
  id INTEGER PRIMARY KEY DEFAULT nextval('user_device_sessions_id_seq'),
  user_id UUID NOT NULL,
  device_id VARCHAR NOT NULL,
  device_name VARCHAR,
  device_type VARCHAR,
  device_os VARCHAR,
  ip_address VARCHAR,
  last_activity TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
