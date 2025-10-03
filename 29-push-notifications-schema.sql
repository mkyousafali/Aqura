-- Create push subscriptions table for device registration
CREATE TABLE IF NOT EXISTS push_subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(100) NOT NULL,
    endpoint TEXT NOT NULL,
    p256dh TEXT NOT NULL,
    auth TEXT NOT NULL,
    device_type VARCHAR(20) NOT NULL CHECK (device_type IN ('mobile', 'desktop')),
    browser_name VARCHAR(50),
    user_agent TEXT,
    is_active BOOLEAN DEFAULT true,
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Unique constraint to prevent duplicate device registrations
    UNIQUE(user_id, device_id)
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON push_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_device_id ON push_subscriptions(device_id);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active ON push_subscriptions(is_active);
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_last_seen ON push_subscriptions(last_seen);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_push_subscriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS trigger_push_subscriptions_updated_at ON push_subscriptions;
CREATE TRIGGER trigger_push_subscriptions_updated_at
    BEFORE UPDATE ON push_subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_push_subscriptions_updated_at();

-- Create notification queue table for reliable delivery
CREATE TABLE IF NOT EXISTS notification_queue (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    notification_id UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(100),
    push_subscription_id UUID REFERENCES push_subscriptions(id) ON DELETE SET NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'delivered')),
    payload JSONB NOT NULL,
    scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sent_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for notification queue
CREATE INDEX IF NOT EXISTS idx_notification_queue_notification_id ON notification_queue(notification_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_user_id ON notification_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_queue_status ON notification_queue(status);
CREATE INDEX IF NOT EXISTS idx_notification_queue_scheduled_at ON notification_queue(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_notification_queue_retry_count ON notification_queue(retry_count);

-- Create function to update notification queue updated_at timestamp
CREATE OR REPLACE FUNCTION update_notification_queue_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for notification queue updated_at
DROP TRIGGER IF EXISTS trigger_notification_queue_updated_at ON notification_queue;
CREATE TRIGGER trigger_notification_queue_updated_at
    BEFORE UPDATE ON notification_queue
    FOR EACH ROW
    EXECUTE FUNCTION update_notification_queue_updated_at();

-- Enhanced user sessions table for multi-device tracking
CREATE TABLE IF NOT EXISTS user_device_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id VARCHAR(100) NOT NULL,
    session_token VARCHAR(255) NOT NULL,
    device_type VARCHAR(20) NOT NULL CHECK (device_type IN ('mobile', 'desktop')),
    browser_name VARCHAR(50),
    user_agent TEXT,
    ip_address INET,
    is_active BOOLEAN DEFAULT true,
    login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '24 hours'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Unique constraint for device sessions
    UNIQUE(user_id, device_id)
);

-- Indexes for user device sessions
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user_id ON user_device_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_device_id ON user_device_sessions(device_id);
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_active ON user_device_sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_expires_at ON user_device_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_last_activity ON user_device_sessions(last_activity);

-- Create function to update device sessions updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_device_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for device sessions updated_at
DROP TRIGGER IF EXISTS trigger_user_device_sessions_updated_at ON user_device_sessions;
CREATE TRIGGER trigger_user_device_sessions_updated_at
    BEFORE UPDATE ON user_device_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_user_device_sessions_updated_at();

-- Function to queue notification for push delivery
CREATE OR REPLACE FUNCTION queue_push_notification(
    p_notification_id UUID,
    p_user_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    notification_record RECORD;
    subscription_record RECORD;
    payload JSONB;
BEGIN
    -- Get notification details
    SELECT n.*, u.username
    INTO notification_record
    FROM notifications n
    LEFT JOIN users u ON n.created_by = u.id
    WHERE n.id = p_notification_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Notification not found: %', p_notification_id;
    END IF;
    
    -- Build notification payload
    payload := jsonb_build_object(
        'title', notification_record.title,
        'body', notification_record.message,
        'icon', '/favicon.png',
        'badge', '/badge-icon.png',
        'data', jsonb_build_object(
            'notification_id', notification_record.id,
            'url', '/notifications?id=' || notification_record.id,
            'created_at', notification_record.created_at,
            'sender', notification_record.username
        )
    );
    
    -- Queue for specific user if provided
    IF p_user_id IS NOT NULL THEN
        -- Get active push subscriptions for the user
        FOR subscription_record IN
            SELECT ps.*
            FROM push_subscriptions ps
            WHERE ps.user_id = p_user_id
            AND ps.is_active = true
            AND ps.last_seen > NOW() - INTERVAL '7 days'
        LOOP
            INSERT INTO notification_queue (
                notification_id,
                user_id,
                device_id,
                push_subscription_id,
                payload
            ) VALUES (
                p_notification_id,
                p_user_id,
                subscription_record.device_id,
                subscription_record.id,
                payload
            );
        END LOOP;
    ELSE
        -- Queue for all target audience if notification type is "all"
        IF notification_record.target_audience_type = 'all' THEN
            FOR subscription_record IN
                SELECT ps.*, u.id as user_id
                FROM push_subscriptions ps
                JOIN users u ON ps.user_id = u.id
                WHERE ps.is_active = true
                AND ps.last_seen > NOW() - INTERVAL '7 days'
                AND u.is_active = true
            LOOP
                INSERT INTO notification_queue (
                    notification_id,
                    user_id,
                    device_id,
                    push_subscription_id,
                    payload
                ) VALUES (
                    p_notification_id,
                    subscription_record.user_id,
                    subscription_record.device_id,
                    subscription_record.id,
                    payload
                );
            END LOOP;
        ELSE
            -- Queue for specific users from notification_recipients
            FOR subscription_record IN
                SELECT ps.*, nr.user_id
                FROM notification_recipients nr
                JOIN push_subscriptions ps ON nr.user_id = ps.user_id
                WHERE nr.notification_id = p_notification_id
                AND ps.is_active = true
                AND ps.last_seen > NOW() - INTERVAL '7 days'
            LOOP
                INSERT INTO notification_queue (
                    notification_id,
                    user_id,
                    device_id,
                    push_subscription_id,
                    payload
                ) VALUES (
                    p_notification_id,
                    subscription_record.user_id,
                    subscription_record.device_id,
                    subscription_record.id,
                    payload
                );
            END LOOP;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up expired sessions and inactive subscriptions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS VOID AS $$
BEGIN
    -- Clean up expired device sessions
    UPDATE user_device_sessions
    SET is_active = false
    WHERE expires_at < NOW()
    AND is_active = true;
    
    -- Mark old push subscriptions as inactive
    UPDATE push_subscriptions
    SET is_active = false
    WHERE last_seen < NOW() - INTERVAL '30 days'
    AND is_active = true;
    
    -- Clean up old notification queue entries
    DELETE FROM notification_queue
    WHERE created_at < NOW() - INTERVAL '7 days'
    AND status IN ('sent', 'delivered', 'failed');
    
    -- Clean up old audit logs (keep last 90 days)
    DELETE FROM user_audit_logs
    WHERE created_at < NOW() - INTERVAL '90 days';
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically queue push notifications when notification is created
CREATE OR REPLACE FUNCTION trigger_queue_push_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Queue push notification for delivery
    PERFORM queue_push_notification(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS trigger_notification_push_queue ON notifications;

-- Create trigger for automatic push notification queuing
CREATE TRIGGER trigger_notification_push_queue
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION trigger_queue_push_notification();

-- RLS policies for push subscriptions
ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;

-- Users can only access their own subscriptions
CREATE POLICY "Users can manage their own push subscriptions" ON push_subscriptions
    FOR ALL
    USING (user_id = auth.uid());

-- Admins can view all subscriptions (based on user_type)
CREATE POLICY "Admins can view all push subscriptions" ON push_subscriptions
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid()
            AND user_type = 'global'
        )
    );

-- RLS policies for notification queue
ALTER TABLE notification_queue ENABLE ROW LEVEL SECURITY;

-- Users can only see their own queued notifications
CREATE POLICY "Users can view their own queued notifications" ON notification_queue
    FOR SELECT
    USING (user_id = auth.uid());

-- System can manage all queue entries
CREATE POLICY "System can manage notification queue" ON notification_queue
    FOR ALL
    USING (true);

-- RLS policies for user device sessions
ALTER TABLE user_device_sessions ENABLE ROW LEVEL SECURITY;

-- Users can only access their own device sessions
CREATE POLICY "Users can manage their own device sessions" ON user_device_sessions
    FOR ALL
    USING (user_id = auth.uid());

-- Admins can view all device sessions (based on user_type)
CREATE POLICY "Admins can view all device sessions" ON user_device_sessions
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid()
            AND user_type = 'global'
        )
    );