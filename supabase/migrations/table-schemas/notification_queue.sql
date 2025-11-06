-- ================================================================
-- TABLE SCHEMA: notification_queue
-- Generated: 2025-11-06T11:09:39.015Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.notification_queue (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    notification_id uuid NOT NULL,
    user_id uuid NOT NULL,
    device_id character varying,
    push_subscription_id uuid,
    status character varying DEFAULT 'pending'::character varying,
    payload jsonb NOT NULL,
    scheduled_at timestamp with time zone DEFAULT now(),
    sent_at timestamp with time zone,
    delivered_at timestamp with time zone,
    error_message text,
    retry_count integer DEFAULT 0,
    max_retries integer DEFAULT 3,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    next_retry_at timestamp with time zone,
    last_attempt_at timestamp with time zone,
    renotification_at timestamp with time zone,
    notification_priority text DEFAULT 'normal'::text
);

-- Table comment
COMMENT ON TABLE public.notification_queue IS 'Table for notification queue management';

-- Column comments
COMMENT ON COLUMN public.notification_queue.id IS 'Primary key identifier';
COMMENT ON COLUMN public.notification_queue.notification_id IS 'Foreign key reference to notification table';
COMMENT ON COLUMN public.notification_queue.user_id IS 'Foreign key reference to user table';
COMMENT ON COLUMN public.notification_queue.device_id IS 'Foreign key reference to device table';
COMMENT ON COLUMN public.notification_queue.push_subscription_id IS 'Foreign key reference to push_subscription table';
COMMENT ON COLUMN public.notification_queue.status IS 'Status indicator';
COMMENT ON COLUMN public.notification_queue.payload IS 'JSON data structure';
COMMENT ON COLUMN public.notification_queue.scheduled_at IS 'scheduled at field';
COMMENT ON COLUMN public.notification_queue.sent_at IS 'sent at field';
COMMENT ON COLUMN public.notification_queue.delivered_at IS 'delivered at field';
COMMENT ON COLUMN public.notification_queue.error_message IS 'error message field';
COMMENT ON COLUMN public.notification_queue.retry_count IS 'retry count field';
COMMENT ON COLUMN public.notification_queue.max_retries IS 'max retries field';
COMMENT ON COLUMN public.notification_queue.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.notification_queue.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.notification_queue.next_retry_at IS 'next retry at field';
COMMENT ON COLUMN public.notification_queue.last_attempt_at IS 'last attempt at field';
COMMENT ON COLUMN public.notification_queue.renotification_at IS 'renotification at field';
COMMENT ON COLUMN public.notification_queue.notification_priority IS 'notification priority field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS notification_queue_pkey ON public.notification_queue USING btree (id);

-- Foreign key index for notification_id
CREATE INDEX IF NOT EXISTS idx_notification_queue_notification_id ON public.notification_queue USING btree (notification_id);

-- Foreign key index for user_id
CREATE INDEX IF NOT EXISTS idx_notification_queue_user_id ON public.notification_queue USING btree (user_id);

-- Foreign key index for device_id
CREATE INDEX IF NOT EXISTS idx_notification_queue_device_id ON public.notification_queue USING btree (device_id);

-- Foreign key index for push_subscription_id
CREATE INDEX IF NOT EXISTS idx_notification_queue_push_subscription_id ON public.notification_queue USING btree (push_subscription_id);

-- Date index for scheduled_at
CREATE INDEX IF NOT EXISTS idx_notification_queue_scheduled_at ON public.notification_queue USING btree (scheduled_at);

-- Date index for sent_at
CREATE INDEX IF NOT EXISTS idx_notification_queue_sent_at ON public.notification_queue USING btree (sent_at);

-- Date index for delivered_at
CREATE INDEX IF NOT EXISTS idx_notification_queue_delivered_at ON public.notification_queue USING btree (delivered_at);

-- Date index for next_retry_at
CREATE INDEX IF NOT EXISTS idx_notification_queue_next_retry_at ON public.notification_queue USING btree (next_retry_at);

-- Date index for last_attempt_at
CREATE INDEX IF NOT EXISTS idx_notification_queue_last_attempt_at ON public.notification_queue USING btree (last_attempt_at);

-- Date index for renotification_at
CREATE INDEX IF NOT EXISTS idx_notification_queue_renotification_at ON public.notification_queue USING btree (renotification_at);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for notification_queue

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.notification_queue ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "notification_queue_select_policy" ON public.notification_queue
    FOR SELECT USING (true);

CREATE POLICY "notification_queue_insert_policy" ON public.notification_queue
    FOR INSERT WITH CHECK (true);

CREATE POLICY "notification_queue_update_policy" ON public.notification_queue
    FOR UPDATE USING (true);

CREATE POLICY "notification_queue_delete_policy" ON public.notification_queue
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for notification_queue

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.notification_queue (notification_id, user_id, device_id)
VALUES ('uuid-example', 'uuid-example', 'example');
*/

-- Select example
/*
SELECT * FROM public.notification_queue 
WHERE notification_id = $1;
*/

-- Update example
/*
UPDATE public.notification_queue 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF NOTIFICATION_QUEUE SCHEMA
-- ================================================================
