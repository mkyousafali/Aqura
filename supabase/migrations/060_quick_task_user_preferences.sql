-- Quick Task User Preferences Table Schema
CREATE TABLE IF NOT EXISTS quick_task_user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE,
  notification_enabled BOOLEAN NOT NULL DEFAULT true,
  notification_frequency VARCHAR NOT NULL DEFAULT 'realtime',
  auto_assign_enabled BOOLEAN NOT NULL DEFAULT false,
  preferred_categories TEXT,
  display_preference VARCHAR NOT NULL DEFAULT 'list',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
