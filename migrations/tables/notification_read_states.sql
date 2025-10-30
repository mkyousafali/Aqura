-- Migration for table: notification_read_states
-- Generated on: 2025-10-30T21:55:45.318Z

CREATE TABLE IF NOT EXISTS public.notification_read_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    notification_id UUID NOT NULL,
    user_id UUID NOT NULL,
    read_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    is_read BOOLEAN DEFAULT false NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notification_read_states_user_id ON public.notification_read_states(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_read_states_created_at ON public.notification_read_states(created_at);

-- Enable Row Level Security
ALTER TABLE public.notification_read_states ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.notification_read_states IS 'Generated from Aqura schema analysis';
