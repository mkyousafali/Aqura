-- Notification Read States Table Schema
CREATE TABLE IF NOT EXISTS notification_read_states (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id UUID NOT NULL,
  user_id TEXT NOT NULL,
  read_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  is_read BOOLEAN NOT NULL DEFAULT false
);
