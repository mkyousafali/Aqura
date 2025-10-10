-- Create notification_recipients table for managing notification delivery to specific recipients
-- This table tracks delivery status and read state for each notification recipient

-- Create the notification_recipients table
CREATE TABLE IF NOT EXISTS public.notification_recipients (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL,
    role CHARACTER VARYING(100) NULL,
    branch_id CHARACTER VARYING(255) NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE NULL,
    is_dismissed BOOLEAN NOT NULL DEFAULT false,
    dismissed_at TIMESTAMP WITH TIME ZONE NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    delivery_status CHARACTER VARYING(20) NULL DEFAULT 'pending'::character varying,
    delivery_attempted_at TIMESTAMP WITH TIME ZONE NULL,
    error_message TEXT NULL,
    user_id UUID NULL,
    
    CONSTRAINT notification_recipients_pkey PRIMARY KEY (id),
    CONSTRAINT unique_notification_recipient UNIQUE (notification_id, user_id),
    CONSTRAINT fk_notification_recipients_user 
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT notification_recipients_notification_fkey 
        FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notification_recipients_delivery_status 
ON public.notification_recipients USING btree (delivery_status) 
TABLESPACE pg_default
WHERE delivery_status::text = ANY (ARRAY[
    'pending'::character varying::text,
    'failed'::character varying::text
]);

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_notification_recipients_notification_id 
ON public.notification_recipients (notification_id);

CREATE INDEX IF NOT EXISTS idx_notification_recipients_user_id 
ON public.notification_recipients (user_id) 
WHERE user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notification_recipients_role 
ON public.notification_recipients (role) 
WHERE role IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notification_recipients_branch_id 
ON public.notification_recipients (branch_id) 
WHERE branch_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notification_recipients_is_read 
ON public.notification_recipients (is_read);

CREATE INDEX IF NOT EXISTS idx_notification_recipients_is_dismissed 
ON public.notification_recipients (is_dismissed);

CREATE INDEX IF NOT EXISTS idx_notification_recipients_created_at 
ON public.notification_recipients (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notification_recipients_read_at 
ON public.notification_recipients (read_at DESC) 
WHERE read_at IS NOT NULL;

-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_notification_recipients_user_unread 
ON public.notification_recipients (user_id, is_read, created_at DESC) 
WHERE user_id IS NOT NULL AND is_read = false;

CREATE INDEX IF NOT EXISTS idx_notification_recipients_role_unread 
ON public.notification_recipients (role, is_read, created_at DESC) 
WHERE role IS NOT NULL AND is_read = false;

CREATE INDEX IF NOT EXISTS idx_notification_recipients_branch_unread 
ON public.notification_recipients (branch_id, is_read, created_at DESC) 
WHERE branch_id IS NOT NULL AND is_read = false;

CREATE INDEX IF NOT EXISTS idx_notification_recipients_notification_status 
ON public.notification_recipients (notification_id, delivery_status, is_read);

CREATE INDEX IF NOT EXISTS idx_notification_recipients_pending_delivery 
ON public.notification_recipients (delivery_status, created_at) 
WHERE delivery_status = 'pending';

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_notification_recipients_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    
    -- Auto-set read_at when marking as read
    IF NEW.is_read = true AND OLD.is_read = false AND NEW.read_at IS NULL THEN
        NEW.read_at = now();
    END IF;
    
    -- Auto-set dismissed_at when marking as dismissed
    IF NEW.is_dismissed = true AND OLD.is_dismissed = false AND NEW.dismissed_at IS NULL THEN
        NEW.dismissed_at = now();
    END IF;
    
    -- Clear read_at when marking as unread
    IF NEW.is_read = false AND OLD.is_read = true THEN
        NEW.read_at = NULL;
    END IF;
    
    -- Clear dismissed_at when marking as not dismissed
    IF NEW.is_dismissed = false AND OLD.is_dismissed = true THEN
        NEW.dismissed_at = NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_notification_recipients_updated_at 
BEFORE UPDATE ON notification_recipients 
FOR EACH ROW 
EXECUTE FUNCTION update_notification_recipients_updated_at();

-- Add data validation constraints
ALTER TABLE public.notification_recipients 
ADD CONSTRAINT chk_read_at_when_read 
CHECK ((is_read = false AND read_at IS NULL) OR (is_read = true AND read_at IS NOT NULL));

ALTER TABLE public.notification_recipients 
ADD CONSTRAINT chk_dismissed_at_when_dismissed 
CHECK ((is_dismissed = false AND dismissed_at IS NULL) OR (is_dismissed = true AND dismissed_at IS NOT NULL));

ALTER TABLE public.notification_recipients 
ADD CONSTRAINT chk_delivery_status_valid 
CHECK (delivery_status IN (
    'pending', 'sent', 'delivered', 'failed', 'processing'
));

ALTER TABLE public.notification_recipients 
ADD CONSTRAINT chk_has_recipient_identifier 
CHECK (user_id IS NOT NULL OR role IS NOT NULL OR branch_id IS NOT NULL);

-- Add table and column comments
COMMENT ON TABLE public.notification_recipients IS 'Tracks notification delivery and read status for specific recipients';
COMMENT ON COLUMN public.notification_recipients.id IS 'Unique identifier for the recipient record';
COMMENT ON COLUMN public.notification_recipients.notification_id IS 'Reference to the notification';
COMMENT ON COLUMN public.notification_recipients.role IS 'Target role for role-based notifications';
COMMENT ON COLUMN public.notification_recipients.branch_id IS 'Target branch for branch-based notifications';
COMMENT ON COLUMN public.notification_recipients.user_id IS 'Specific user recipient';
COMMENT ON COLUMN public.notification_recipients.is_read IS 'Whether the recipient has read the notification';
COMMENT ON COLUMN public.notification_recipients.read_at IS 'Timestamp when the notification was read';
COMMENT ON COLUMN public.notification_recipients.is_dismissed IS 'Whether the recipient has dismissed the notification';
COMMENT ON COLUMN public.notification_recipients.dismissed_at IS 'Timestamp when the notification was dismissed';
COMMENT ON COLUMN public.notification_recipients.delivery_status IS 'Current delivery status of the notification';
COMMENT ON COLUMN public.notification_recipients.delivery_attempted_at IS 'Last delivery attempt timestamp';
COMMENT ON COLUMN public.notification_recipients.error_message IS 'Error details if delivery failed';

-- Create view for unread notifications by recipient type
CREATE OR REPLACE VIEW unread_notifications_by_recipient AS
SELECT 
    nr.id,
    nr.notification_id,
    n.title,
    n.message,
    n.type,
    n.priority,
    nr.user_id,
    nr.role,
    nr.branch_id,
    nr.delivery_status,
    nr.created_at,
    'user' as recipient_type
FROM notification_recipients nr
JOIN notifications n ON nr.notification_id = n.id
WHERE nr.is_read = false AND nr.user_id IS NOT NULL

UNION ALL

SELECT 
    nr.id,
    nr.notification_id,
    n.title,
    n.message,
    n.type,
    n.priority,
    nr.user_id,
    nr.role,
    nr.branch_id,
    nr.delivery_status,
    nr.created_at,
    'role' as recipient_type
FROM notification_recipients nr
JOIN notifications n ON nr.notification_id = n.id
WHERE nr.is_read = false AND nr.role IS NOT NULL

UNION ALL

SELECT 
    nr.id,
    nr.notification_id,
    n.title,
    n.message,
    n.type,
    n.priority,
    nr.user_id,
    nr.role,
    nr.branch_id,
    nr.delivery_status,
    nr.created_at,
    'branch' as recipient_type
FROM notification_recipients nr
JOIN notifications n ON nr.notification_id = n.id
WHERE nr.is_read = false AND nr.branch_id IS NOT NULL

ORDER BY created_at DESC;

-- Create function to mark recipient notification as read
CREATE OR REPLACE FUNCTION mark_recipient_notification_read(recipient_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notification_recipients 
    SET is_read = true,
        read_at = now(),
        updated_at = now()
    WHERE id = recipient_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to mark recipient notification as dismissed
CREATE OR REPLACE FUNCTION mark_recipient_notification_dismissed(recipient_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notification_recipients 
    SET is_dismissed = true,
        dismissed_at = now(),
        updated_at = now()
    WHERE id = recipient_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get user notifications with recipient status
CREATE OR REPLACE FUNCTION get_user_recipient_notifications(
    target_user_id UUID,
    limit_count INTEGER DEFAULT 50,
    include_read BOOLEAN DEFAULT true
)
RETURNS TABLE(
    recipient_id UUID,
    notification_id UUID,
    title VARCHAR,
    message TEXT,
    type VARCHAR,
    priority VARCHAR,
    is_read BOOLEAN,
    read_at TIMESTAMPTZ,
    is_dismissed BOOLEAN,
    dismissed_at TIMESTAMPTZ,
    delivery_status VARCHAR,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        nr.id,
        nr.notification_id,
        n.title,
        n.message,
        n.type,
        n.priority,
        nr.is_read,
        nr.read_at,
        nr.is_dismissed,
        nr.dismissed_at,
        nr.delivery_status,
        nr.created_at
    FROM notification_recipients nr
    JOIN notifications n ON nr.notification_id = n.id
    WHERE nr.user_id = target_user_id
      AND (include_read = true OR nr.is_read = false)
      AND nr.is_dismissed = false
    ORDER BY nr.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to get notification delivery statistics
CREATE OR REPLACE FUNCTION get_notification_delivery_stats(notif_id UUID)
RETURNS TABLE(
    total_recipients BIGINT,
    pending_count BIGINT,
    sent_count BIGINT,
    delivered_count BIGINT,
    failed_count BIGINT,
    read_count BIGINT,
    dismissed_count BIGINT,
    delivery_rate NUMERIC,
    read_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_recipients,
        COUNT(*) FILTER (WHERE delivery_status = 'pending') as pending_count,
        COUNT(*) FILTER (WHERE delivery_status = 'sent') as sent_count,
        COUNT(*) FILTER (WHERE delivery_status = 'delivered') as delivered_count,
        COUNT(*) FILTER (WHERE delivery_status = 'failed') as failed_count,
        COUNT(*) FILTER (WHERE is_read = true) as read_count,
        COUNT(*) FILTER (WHERE is_dismissed = true) as dismissed_count,
        CASE 
            WHEN COUNT(*) > 0 
            THEN ROUND((COUNT(*) FILTER (WHERE delivery_status IN ('sent', 'delivered')) * 100.0) / COUNT(*), 2)
            ELSE 0
        END as delivery_rate,
        CASE 
            WHEN COUNT(*) > 0 
            THEN ROUND((COUNT(*) FILTER (WHERE is_read = true) * 100.0) / COUNT(*), 2)
            ELSE 0
        END as read_rate
    FROM notification_recipients
    WHERE notification_id = notif_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update delivery status
CREATE OR REPLACE FUNCTION update_recipient_delivery_status(
    recipient_id UUID,
    new_status VARCHAR,
    error_msg TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notification_recipients 
    SET delivery_status = new_status,
        delivery_attempted_at = now(),
        error_message = error_msg,
        updated_at = now()
    WHERE id = recipient_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get pending deliveries
CREATE OR REPLACE FUNCTION get_pending_deliveries(limit_count INTEGER DEFAULT 100)
RETURNS TABLE(
    recipient_id UUID,
    notification_id UUID,
    user_id UUID,
    role VARCHAR,
    branch_id VARCHAR,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        nr.id,
        nr.notification_id,
        nr.user_id,
        nr.role,
        nr.branch_id,
        nr.created_at
    FROM notification_recipients nr
    WHERE nr.delivery_status = 'pending'
    ORDER BY nr.created_at ASC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'notification_recipients table created with comprehensive recipient tracking features';