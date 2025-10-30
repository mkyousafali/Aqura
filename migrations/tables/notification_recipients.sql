-- Migration for table: notification_recipients
-- Generated on: 2025-10-30T21:55:45.311Z

CREATE TABLE IF NOT EXISTS public.notification_recipients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    notification_id UUID NOT NULL,
    role JSONB,
    branch_id UUID,
    is_read BOOLEAN DEFAULT false NOT NULL,
    read_at JSONB,
    is_dismissed BOOLEAN DEFAULT false NOT NULL,
    dismissed_at JSONB,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    delivery_status VARCHAR(50) NOT NULL,
    delivery_attempted_at TIMESTAMPTZ NOT NULL,
    error_message JSONB,
    user_id UUID NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notification_recipients_branch_id ON public.notification_recipients(branch_id);
CREATE INDEX IF NOT EXISTS idx_notification_recipients_created_at ON public.notification_recipients(created_at);
CREATE INDEX IF NOT EXISTS idx_notification_recipients_updated_at ON public.notification_recipients(updated_at);
CREATE INDEX IF NOT EXISTS idx_notification_recipients_delivery_status ON public.notification_recipients(delivery_status);
CREATE INDEX IF NOT EXISTS idx_notification_recipients_user_id ON public.notification_recipients(user_id);

-- Enable Row Level Security
ALTER TABLE public.notification_recipients ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_notification_recipients_updated_at
    BEFORE UPDATE ON public.notification_recipients
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.notification_recipients IS 'Generated from Aqura schema analysis';
