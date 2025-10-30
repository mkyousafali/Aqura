-- Migration for table: push_subscriptions
-- Generated on: 2025-10-30T21:55:45.272Z

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    user_id UUID NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    endpoint TEXT NOT NULL,
    p256dh TEXT NOT NULL,
    auth VARCHAR(255) NOT NULL,
    device_type VARCHAR(50) NOT NULL,
    browser_name VARCHAR(255) NOT NULL,
    user_agent TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    last_seen TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    session_id JSONB
);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON public.push_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_device_type ON public.push_subscriptions(device_type);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_created_at ON public.push_subscriptions(created_at);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_updated_at ON public.push_subscriptions(updated_at);

-- Enable Row Level Security
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Add updated_at trigger
CREATE TRIGGER set_push_subscriptions_updated_at
    BEFORE UPDATE ON public.push_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION public.set_updated_at();

-- Table comments
COMMENT ON TABLE public.push_subscriptions IS 'Generated from Aqura schema analysis';
