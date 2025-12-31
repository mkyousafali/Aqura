-- User Sessions Table Schema
CREATE TABLE IF NOT EXISTS user_sessions (
  id INTEGER PRIMARY KEY DEFAULT nextval('user_sessions_id_seq'),
  user_id UUID NOT NULL,
  session_token VARCHAR NOT NULL UNIQUE,
  ip_address VARCHAR,
  user_agent VARCHAR,
  login_time TIMESTAMP WITH TIME ZONE DEFAULT now(),
  last_activity TIMESTAMP WITH TIME ZONE,
  logout_time TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  device_info JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
