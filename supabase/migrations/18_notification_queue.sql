-- Create notification_queue table for managing push notification delivery queue
-- This table handles notification queuing, retry logic, and delivery tracking

-- Create the notification_queue table
CREATE TABLE IF NOT EXISTS public.notification_queue (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL,
    user_id UUID NOT NULL,
    device_id CHARACTER VARYING(100) NULL,
    push_subscription_id UUID NULL,
    status CHARACTER VARYING(20) NULL DEFAULT 'pending'::character varying,
    payload JSONB NOT NULL,
    scheduled_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    sent_at TIMESTAMP WITH TIME ZONE NULL,
    delivered_at TIMESTAMP WITH TIME ZONE NULL,
    error_message TEXT NULL,
    retry_count INTEGER NULL DEFAULT 0,
    max_retries INTEGER NULL DEFAULT 3,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    next_retry_at TIMESTAMP WITH TIME ZONE NULL,
    last_attempt_at TIMESTAMP WITH TIME ZONE NULL,
    
    CONSTRAINT notification_queue_pkey PRIMARY KEY (id),
    CONSTRAINT notification_queue_notification_id_fkey 
        FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE,
    CONSTRAINT notification_queue_push_subscription_id_fkey 
        FOREIGN KEY (push_subscription_id) REFERENCES push_subscriptions (id) ON DELETE SET NULL,
    CONSTRAINT notification_queue_user_id_fkey 
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT notification_queue_status_check 
        CHECK (status::text = ANY (ARRAY[
            'pending'::character varying::text,
            'sent'::character varying::text,
            'delivered'::character varying::text,
            'failed'::character varying::text,
            'retry'::character varying::text,
            'processing'::character varying::text
        ]))
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notification_queue_notification_id 
ON public.notification_queue USING btree (notification_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_user_id 
ON public.notification_queue USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_status 
ON public.notification_queue USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_scheduled_at 
ON public.notification_queue USING btree (scheduled_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_retry_count 
ON public.notification_queue USING btree (retry_count) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_retry 
ON public.notification_queue USING btree (status, next_retry_at) 
TABLESPACE pg_default
WHERE status::text = 'retry'::text AND next_retry_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notification_queue_processing 
ON public.notification_queue USING btree (status, last_attempt_at) 
TABLESPACE pg_default
WHERE status::text = ANY (ARRAY[
    'pending'::character varying::text,
    'processing'::character varying::text,
    'retry'::character varying::text
]);

CREATE INDEX IF NOT EXISTS idx_notification_queue_lookup 
ON public.notification_queue USING btree (notification_id, user_id, device_id, status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_notification_user_subscription 
ON public.notification_queue USING btree (notification_id, user_id, push_subscription_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_duplicate_prevention 
ON public.notification_queue USING btree (
    notification_id,
    user_id,
    push_subscription_id,
    device_id
) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_status_created 
ON public.notification_queue USING btree (status, created_at) 
TABLESPACE pg_default;

-- Create additional performance indexes
CREATE INDEX IF NOT EXISTS idx_notification_queue_pending_scheduled 
ON public.notification_queue (scheduled_at) 
WHERE status = 'pending' AND scheduled_at <= now();

CREATE INDEX IF NOT EXISTS idx_notification_queue_failed_retries 
ON public.notification_queue (retry_count, max_retries, status) 
WHERE status IN ('failed', 'retry');

CREATE INDEX IF NOT EXISTS idx_notification_queue_subscription_status 
ON public.notification_queue (push_subscription_id, status) 
WHERE push_subscription_id IS NOT NULL;

-- Create GIN index for payload searches
CREATE INDEX IF NOT EXISTS idx_notification_queue_payload_gin 
ON public.notification_queue USING gin (payload);

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION update_notification_queue_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trigger_notification_queue_updated_at 
BEFORE UPDATE ON notification_queue 
FOR EACH ROW 
EXECUTE FUNCTION update_notification_queue_updated_at();

-- Add data validation constraints
ALTER TABLE public.notification_queue 
ADD CONSTRAINT chk_retry_count_non_negative 
CHECK (retry_count >= 0);

ALTER TABLE public.notification_queue 
ADD CONSTRAINT chk_max_retries_positive 
CHECK (max_retries > 0);

ALTER TABLE public.notification_queue 
ADD CONSTRAINT chk_retry_count_within_max 
CHECK (retry_count <= max_retries + 1);

ALTER TABLE public.notification_queue 
ADD CONSTRAINT chk_sent_after_scheduled 
CHECK (sent_at IS NULL OR sent_at >= scheduled_at);

ALTER TABLE public.notification_queue 
ADD CONSTRAINT chk_delivered_after_sent 
CHECK (delivered_at IS NULL OR (sent_at IS NOT NULL AND delivered_at >= sent_at));

-- Add table and column comments
COMMENT ON TABLE public.notification_queue IS 'Queue for managing push notification delivery with retry logic';
COMMENT ON COLUMN public.notification_queue.id IS 'Unique identifier for the queue item';
COMMENT ON COLUMN public.notification_queue.notification_id IS 'Reference to the notification being queued';
COMMENT ON COLUMN public.notification_queue.user_id IS 'Target user for the notification';
COMMENT ON COLUMN public.notification_queue.device_id IS 'Specific device identifier if applicable';
COMMENT ON COLUMN public.notification_queue.push_subscription_id IS 'Push subscription to use for delivery';
COMMENT ON COLUMN public.notification_queue.status IS 'Current status of the notification delivery';
COMMENT ON COLUMN public.notification_queue.payload IS 'Notification payload data in JSON format';
COMMENT ON COLUMN public.notification_queue.scheduled_at IS 'When the notification should be sent';
COMMENT ON COLUMN public.notification_queue.sent_at IS 'When the notification was actually sent';
COMMENT ON COLUMN public.notification_queue.delivered_at IS 'When delivery was confirmed';
COMMENT ON COLUMN public.notification_queue.error_message IS 'Error details if delivery failed';
COMMENT ON COLUMN public.notification_queue.retry_count IS 'Number of retry attempts made';
COMMENT ON COLUMN public.notification_queue.max_retries IS 'Maximum number of retries allowed';
COMMENT ON COLUMN public.notification_queue.next_retry_at IS 'When the next retry should be attempted';
COMMENT ON COLUMN public.notification_queue.last_attempt_at IS 'When the last delivery attempt was made';

-- Create view for queue monitoring
CREATE OR REPLACE VIEW notification_queue_status AS
SELECT 
    status,
    COUNT(*) as count,
    MIN(created_at) as oldest_created,
    MAX(created_at) as newest_created,
    AVG(retry_count) as avg_retry_count,
    COUNT(*) FILTER (WHERE retry_count >= max_retries) as max_retries_reached
FROM notification_queue
GROUP BY status
ORDER BY 
    CASE status
        WHEN 'pending' THEN 1
        WHEN 'processing' THEN 2
        WHEN 'retry' THEN 3
        WHEN 'sent' THEN 4
        WHEN 'delivered' THEN 5
        WHEN 'failed' THEN 6
        ELSE 7
    END;

-- Create function to get pending notifications ready for processing
CREATE OR REPLACE FUNCTION get_pending_notifications(batch_size INTEGER DEFAULT 100)
RETURNS TABLE(
    queue_id UUID,
    notification_id UUID,
    user_id UUID,
    device_id VARCHAR,
    push_subscription_id UUID,
    payload JSONB,
    retry_count INTEGER,
    max_retries INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        nq.id,
        nq.notification_id,
        nq.user_id,
        nq.device_id,
        nq.push_subscription_id,
        nq.payload,
        nq.retry_count,
        nq.max_retries
    FROM notification_queue nq
    WHERE (nq.status = 'pending' AND nq.scheduled_at <= now())
       OR (nq.status = 'retry' AND nq.next_retry_at <= now())
    ORDER BY nq.scheduled_at ASC, nq.created_at ASC
    LIMIT batch_size
    FOR UPDATE SKIP LOCKED;
END;
$$ LANGUAGE plpgsql;

-- Create function to mark notification as processing
CREATE OR REPLACE FUNCTION mark_notification_processing(queue_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notification_queue 
    SET status = 'processing',
        last_attempt_at = now(),
        updated_at = now()
    WHERE id = queue_id 
      AND status IN ('pending', 'retry');
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to mark notification as sent
CREATE OR REPLACE FUNCTION mark_notification_sent(queue_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE notification_queue 
    SET status = 'sent',
        sent_at = now(),
        updated_at = now()
    WHERE id = queue_id 
      AND status = 'processing';
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to mark notification as failed with retry logic
CREATE OR REPLACE FUNCTION mark_notification_failed(
    queue_id UUID, 
    error_msg TEXT,
    retry_delay_minutes INTEGER DEFAULT 5
)
RETURNS VARCHAR AS $$
DECLARE
    current_retry_count INTEGER;
    current_max_retries INTEGER;
    new_status VARCHAR;
BEGIN
    SELECT retry_count, max_retries 
    INTO current_retry_count, current_max_retries
    FROM notification_queue 
    WHERE id = queue_id;
    
    IF current_retry_count < current_max_retries THEN
        new_status := 'retry';
        UPDATE notification_queue 
        SET status = new_status,
            retry_count = retry_count + 1,
            error_message = error_msg,
            next_retry_at = now() + (retry_delay_minutes * INTERVAL '1 minute'),
            updated_at = now()
        WHERE id = queue_id;
    ELSE
        new_status := 'failed';
        UPDATE notification_queue 
        SET status = new_status,
            retry_count = retry_count + 1,
            error_message = error_msg,
            updated_at = now()
        WHERE id = queue_id;
    END IF;
    
    RETURN new_status;
END;
$$ LANGUAGE plpgsql;

-- Create function to get queue statistics
CREATE OR REPLACE FUNCTION get_queue_statistics()
RETURNS TABLE(
    total_queued BIGINT,
    pending_count BIGINT,
    processing_count BIGINT,
    sent_count BIGINT,
    delivered_count BIGINT,
    failed_count BIGINT,
    retry_count BIGINT,
    avg_processing_time INTERVAL,
    oldest_pending TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_queued,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
        COUNT(*) FILTER (WHERE status = 'processing') as processing_count,
        COUNT(*) FILTER (WHERE status = 'sent') as sent_count,
        COUNT(*) FILTER (WHERE status = 'delivered') as delivered_count,
        COUNT(*) FILTER (WHERE status = 'failed') as failed_count,
        COUNT(*) FILTER (WHERE status = 'retry') as retry_count,
        AVG(sent_at - last_attempt_at) FILTER (WHERE sent_at IS NOT NULL AND last_attempt_at IS NOT NULL) as avg_processing_time,
        MIN(created_at) FILTER (WHERE status = 'pending') as oldest_pending
    FROM notification_queue;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up old completed notifications
CREATE OR REPLACE FUNCTION cleanup_old_queue_items(days_to_keep INTEGER DEFAULT 30)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM notification_queue 
    WHERE status IN ('delivered', 'failed')
      AND updated_at < now() - (days_to_keep * INTERVAL '1 day');
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'notification_queue table created with comprehensive delivery management features';