-- Migration for table: notification_queue
-- Generated on: 2025-10-30T21:55:45.296Z

CREATE TABLE IF NOT EXISTS public.notification_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    notification_id UUID NOT NULL,
    user_id UUID NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    push_subscription_id UUID NOT NULL,
    status VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    scheduled_at TIMESTAMPTZ NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL,
    delivered_at JSONB,
    error_message JSONB,
    retry_count NUMERIC NOT NULL,
    max_retries NUMERIC NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    next_retry_at JSONB,
    last_attempt_at TIMESTAMPTZ NOT NULL,
    renotification_at JSONB,
    notification_priority VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_notification_queue_user_id ON public.notification_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_status ON public.notification_queue(status);
CREATE INDEX IF NOT EXISTS idx_notification_queue_created_at ON public.notification_queue(created_at);
CREATE INDEX IF NOT EXISTS idx_notification_queue_updated_at ON public.notification_queue(updated_at);

-- Enable Row Level Security
ALTER TABLE public.notification_queue ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_notification_queue_updated_at
    BEFORE UPDATE ON public.notification_queue
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.notification_queue IS 'Generated from Aqura schema analysis';
