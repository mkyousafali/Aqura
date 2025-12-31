-- Button Permissions Table Schema
CREATE TABLE IF NOT EXISTS button_permissions (
  id BIGINT PRIMARY KEY,
  user_id UUID NOT NULL,
  button_id BIGINT NOT NULL,
  is_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
