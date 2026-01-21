-- Create push_subscriptions table for web push notifications
-- This table stores user device registrations for push notifications

CREATE TABLE IF NOT EXISTS push_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- The full push subscription object (includes endpoint, keys, etc.)
    subscription JSONB NOT NULL,
    
    -- Store endpoint separately for quick lookups and deduplication
    endpoint TEXT NOT NULL,
    
    -- User agent info for debugging
    user_agent TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Last time this subscription was successfully used
    last_used_at TIMESTAMPTZ,
    
    -- Track failed deliveries
    failed_deliveries INTEGER DEFAULT 0,
    
    -- Disable subscription after too many failures
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Unique constraint: one subscription per endpoint
    UNIQUE(endpoint)
);

-- Create index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id 
ON push_subscriptions(user_id);

-- Create index for active subscriptions
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active 
ON push_subscriptions(user_id, is_active) 
WHERE is_active = TRUE;

-- Enable Row Level Security
ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Simple permissive policy for all operations (matching app pattern)
CREATE POLICY "Allow all access to push_subscriptions"
ON push_subscriptions
FOR ALL
USING (true)
WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON push_subscriptions TO authenticated;
GRANT ALL ON push_subscriptions TO service_role;
GRANT ALL ON push_subscriptions TO anon;

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_push_subscriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to call the function before updates
CREATE TRIGGER set_push_subscriptions_updated_at
BEFORE UPDATE ON push_subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_push_subscriptions_updated_at();

-- Comment on table
COMMENT ON TABLE push_subscriptions IS 'Stores web push notification subscriptions for users';
COMMENT ON COLUMN push_subscriptions.subscription IS 'Full PushSubscription object in JSON format';
COMMENT ON COLUMN push_subscriptions.endpoint IS 'Push service endpoint URL for deduplication';
COMMENT ON COLUMN push_subscriptions.failed_deliveries IS 'Count of consecutive failed push attempts';
COMMENT ON COLUMN push_subscriptions.is_active IS 'Whether this subscription is active and should receive pushes';
