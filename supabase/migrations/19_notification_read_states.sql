-- Create notification_read_states table for tracking notification read status by users
-- This table manages per-user read state for notifications

-- Create the notification_read_states table
CREATE TABLE IF NOT EXISTS public.notification_read_states (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL,
    user_id TEXT NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    is_read BOOLEAN NOT NULL DEFAULT false,
    
    CONSTRAINT notification_read_states_pkey PRIMARY KEY (id),
    CONSTRAINT notification_read_states_notification_id_user_id_key 
        UNIQUE (notification_id, user_id),
    CONSTRAINT notification_read_states_notification_id_fkey 
        FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_id 
ON public.notification_read_states USING btree (notification_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_read_states_user_id 
ON public.notification_read_states USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_user 
ON public.notification_read_states USING btree (notification_id, user_id) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_notification_read_states_is_read 
ON public.notification_read_states (is_read);

CREATE INDEX IF NOT EXISTS idx_notification_read_states_read_at 
ON public.notification_read_states (read_at) 
WHERE read_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notification_read_states_unread 
ON public.notification_read_states (user_id, created_at DESC) 
WHERE is_read = false;

CREATE INDEX IF NOT EXISTS idx_notification_read_states_user_read_status 
ON public.notification_read_states (user_id, is_read, read_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_read_states_notification_read_count 
ON public.notification_read_states (notification_id, is_read);

-- Add updated_at column and trigger
ALTER TABLE public.notification_read_states 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_notification_read_states_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    
    -- Auto-set read_at when marking as read
    IF NEW.is_read = true AND OLD.is_read = false AND NEW.read_at IS NULL THEN
        NEW.read_at = now();
    END IF;
    
    -- Clear read_at when marking as unread
    IF NEW.is_read = false AND OLD.is_read = true THEN
        NEW.read_at = NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_notification_read_states_updated_at 
BEFORE UPDATE ON notification_read_states 
FOR EACH ROW 
EXECUTE FUNCTION update_notification_read_states_updated_at();

-- Add data validation constraints
ALTER TABLE public.notification_read_states 
ADD CONSTRAINT chk_read_at_when_read 
CHECK ((is_read = false AND read_at IS NULL) OR (is_read = true AND read_at IS NOT NULL));

ALTER TABLE public.notification_read_states 
ADD CONSTRAINT chk_read_at_after_created 
CHECK (read_at IS NULL OR read_at >= created_at);

-- Add table and column comments
COMMENT ON TABLE public.notification_read_states IS 'Tracks read status of notifications for each user';
COMMENT ON COLUMN public.notification_read_states.id IS 'Unique identifier for the read state record';
COMMENT ON COLUMN public.notification_read_states.notification_id IS 'Reference to the notification';
COMMENT ON COLUMN public.notification_read_states.user_id IS 'User identifier (can be username or UUID as text)';
COMMENT ON COLUMN public.notification_read_states.read_at IS 'Timestamp when the notification was marked as read';
COMMENT ON COLUMN public.notification_read_states.created_at IS 'Timestamp when the read state record was created';
COMMENT ON COLUMN public.notification_read_states.is_read IS 'Whether the notification has been read by this user';
COMMENT ON COLUMN public.notification_read_states.updated_at IS 'Timestamp when the read state was last updated';

-- Create view for unread notifications by user
CREATE OR REPLACE VIEW user_unread_notifications AS
SELECT 
    nrs.user_id,
    nrs.notification_id,
    n.title,
    n.message,
    n.type,
    n.priority,
    n.created_at as notification_created,
    nrs.created_at as state_created
FROM notification_read_states nrs
JOIN notifications n ON nrs.notification_id = n.id
WHERE nrs.is_read = false
ORDER BY nrs.user_id, n.created_at DESC;

-- Create function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(notif_id UUID, user_identifier TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO notification_read_states (notification_id, user_id, is_read, read_at)
    VALUES (notif_id, user_identifier, true, now())
    ON CONFLICT (notification_id, user_id)
    DO UPDATE SET 
        is_read = true,
        read_at = now(),
        updated_at = now();
    
    RETURN true;
EXCEPTION
    WHEN OTHERS THEN
        RETURN false;
END;
$$ LANGUAGE plpgsql;

-- Create function to mark notification as unread
CREATE OR REPLACE FUNCTION mark_notification_unread(notif_id UUID, user_identifier TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO notification_read_states (notification_id, user_id, is_read, read_at)
    VALUES (notif_id, user_identifier, false, NULL)
    ON CONFLICT (notification_id, user_id)
    DO UPDATE SET 
        is_read = false,
        read_at = NULL,
        updated_at = now();
    
    RETURN true;
EXCEPTION
    WHEN OTHERS THEN
        RETURN false;
END;
$$ LANGUAGE plpgsql;

-- Create function to get unread count for user
CREATE OR REPLACE FUNCTION get_unread_count(user_identifier TEXT)
RETURNS INTEGER AS $$
BEGIN
    RETURN (
        SELECT COUNT(*)::INTEGER
        FROM notification_read_states nrs
        JOIN notifications n ON nrs.notification_id = n.id
        WHERE nrs.user_id = user_identifier 
          AND nrs.is_read = false
    );
END;
$$ LANGUAGE plpgsql;

-- Create function to get user notifications with read status
CREATE OR REPLACE FUNCTION get_user_notifications(
    user_identifier TEXT,
    limit_count INTEGER DEFAULT 50,
    offset_count INTEGER DEFAULT 0,
    include_read BOOLEAN DEFAULT true
)
RETURNS TABLE(
    notification_id UUID,
    title VARCHAR,
    message TEXT,
    type VARCHAR,
    priority VARCHAR,
    is_read BOOLEAN,
    read_at TIMESTAMPTZ,
    notification_created TIMESTAMPTZ,
    state_created TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.id,
        n.title,
        n.message,
        n.type,
        n.priority,
        COALESCE(nrs.is_read, false) as is_read,
        nrs.read_at,
        n.created_at as notification_created,
        nrs.created_at as state_created
    FROM notifications n
    LEFT JOIN notification_read_states nrs ON (
        n.id = nrs.notification_id 
        AND nrs.user_id = user_identifier
    )
    WHERE include_read = true OR COALESCE(nrs.is_read, false) = false
    ORDER BY n.created_at DESC
    LIMIT limit_count
    OFFSET offset_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to mark all notifications as read for user
CREATE OR REPLACE FUNCTION mark_all_notifications_read(user_identifier TEXT)
RETURNS INTEGER AS $$
DECLARE
    affected_count INTEGER;
BEGIN
    WITH unread_notifications AS (
        SELECT n.id as notification_id
        FROM notifications n
        LEFT JOIN notification_read_states nrs ON (
            n.id = nrs.notification_id 
            AND nrs.user_id = user_identifier
        )
        WHERE COALESCE(nrs.is_read, false) = false
    )
    INSERT INTO notification_read_states (notification_id, user_id, is_read, read_at)
    SELECT notification_id, user_identifier, true, now()
    FROM unread_notifications
    ON CONFLICT (notification_id, user_id)
    DO UPDATE SET 
        is_read = true,
        read_at = now(),
        updated_at = now();
    
    GET DIAGNOSTICS affected_count = ROW_COUNT;
    RETURN affected_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get notification read statistics
CREATE OR REPLACE FUNCTION get_notification_read_stats(notif_id UUID)
RETURNS TABLE(
    total_recipients BIGINT,
    read_count BIGINT,
    unread_count BIGINT,
    read_percentage NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_recipients,
        COUNT(*) FILTER (WHERE is_read = true) as read_count,
        COUNT(*) FILTER (WHERE is_read = false) as unread_count,
        CASE 
            WHEN COUNT(*) > 0 
            THEN ROUND((COUNT(*) FILTER (WHERE is_read = true) * 100.0) / COUNT(*), 2)
            ELSE 0
        END as read_percentage
    FROM notification_read_states
    WHERE notification_id = notif_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up old read states
CREATE OR REPLACE FUNCTION cleanup_old_read_states(days_to_keep INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notification_read_states nrs
    WHERE nrs.created_at < now() - (days_to_keep * INTERVAL '1 day')
      AND NOT EXISTS (
          SELECT 1 FROM notifications n 
          WHERE n.id = nrs.notification_id 
            AND n.created_at >= now() - (days_to_keep * INTERVAL '1 day')
      );
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get read state summary by user
CREATE OR REPLACE FUNCTION get_user_read_summary(user_identifier TEXT)
RETURNS TABLE(
    total_notifications BIGINT,
    read_notifications BIGINT,
    unread_notifications BIGINT,
    read_percentage NUMERIC,
    latest_read_at TIMESTAMPTZ,
    oldest_unread_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_notifications,
        COUNT(*) FILTER (WHERE nrs.is_read = true) as read_notifications,
        COUNT(*) FILTER (WHERE nrs.is_read = false) as unread_notifications,
        CASE 
            WHEN COUNT(*) > 0 
            THEN ROUND((COUNT(*) FILTER (WHERE nrs.is_read = true) * 100.0) / COUNT(*), 2)
            ELSE 0
        END as read_percentage,
        MAX(nrs.read_at) as latest_read_at,
        MIN(n.created_at) FILTER (WHERE nrs.is_read = false) as oldest_unread_at
    FROM notifications n
    LEFT JOIN notification_read_states nrs ON (
        n.id = nrs.notification_id 
        AND nrs.user_id = user_identifier
    );
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'notification_read_states table created with comprehensive read tracking features';