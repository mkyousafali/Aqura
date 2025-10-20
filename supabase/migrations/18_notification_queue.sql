-- Migration: Create notification_queue table
-- File: 18_notification_queue.sql
-- Description: Creates the notification_queue table for managing notification delivery queue and status tracking

BEGIN;

-- Create trigger function for notification queue
CREATE OR REPLACE FUNCTION update_notification_queue_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create notification_queue table
CREATE TABLE public.notification_queue (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  notification_id uuid NOT NULL,
  user_id uuid NOT NULL,
  device_id character varying(100) NULL,
  push_subscription_id uuid NULL,
  status character varying(20) NULL DEFAULT 'pending'::character varying,
  payload jsonb NOT NULL,
  scheduled_at timestamp with time zone NULL DEFAULT now(),
  sent_at timestamp with time zone NULL,
  delivered_at timestamp with time zone NULL,
  error_message text NULL,
  retry_count integer NULL DEFAULT 0,
  max_retries integer NULL DEFAULT 3,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  next_retry_at timestamp with time zone NULL,
  last_attempt_at timestamp with time zone NULL,
  CONSTRAINT notification_queue_pkey PRIMARY KEY (id),
  CONSTRAINT notification_queue_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE,
  CONSTRAINT notification_queue_push_subscription_id_fkey FOREIGN KEY (push_subscription_id) REFERENCES push_subscriptions (id) ON DELETE SET NULL,
  CONSTRAINT notification_queue_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT notification_queue_status_check CHECK (
    (
      (status)::text = ANY (
        (
          ARRAY[
            'pending'::character varying,
            'sent'::character varying,
            'delivered'::character varying,
            'failed'::character varying,
            'retry'::character varying,
            'processing'::character varying
          ]
        )::text[]
      )
    )
  )
) TABLESPACE pg_default;

-- Create indexes
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
WHERE (
  ((status)::text = 'retry'::text)
  AND (next_retry_at IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_notification_queue_processing 
ON public.notification_queue USING btree (status, last_attempt_at) 
TABLESPACE pg_default
WHERE (
  (status)::text = ANY (
    (
      ARRAY[
        'pending'::character varying,
        'processing'::character varying,
        'retry'::character varying
      ]
    )::text[]
  )
);

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

-- Create trigger
CREATE TRIGGER trigger_notification_queue_updated_at 
BEFORE UPDATE ON notification_queue 
FOR EACH ROW
EXECUTE FUNCTION update_notification_queue_updated_at();

COMMIT;