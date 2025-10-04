-- Notification Queue Schema
-- This table manages notification delivery queue with retry logic and status tracking

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
  CONSTRAINT notification_queue_pkey PRIMARY KEY (id),
  CONSTRAINT notification_queue_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES notifications (id) ON DELETE CASCADE,
  CONSTRAINT notification_queue_push_subscription_id_fkey FOREIGN KEY (push_subscription_id) REFERENCES push_subscriptions (id) ON DELETE SET NULL,
  CONSTRAINT notification_queue_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT notification_queue_status_check CHECK (
    (status)::text = ANY (
      (
        ARRAY[
          'pending'::character varying,
          'sent'::character varying,
          'failed'::character varying,
          'delivered'::character varying
        ]
      )::text[]
    )
  )
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_notification_queue_notification_id ON public.notification_queue USING btree (notification_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_user_id ON public.notification_queue USING btree (user_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_status ON public.notification_queue USING btree (status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_scheduled_at ON public.notification_queue USING btree (scheduled_at) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_notification_queue_retry_count ON public.notification_queue USING btree (retry_count) TABLESPACE pg_default;

-- Trigger to update the updated_at timestamp
CREATE TRIGGER trigger_notification_queue_updated_at BEFORE UPDATE ON notification_queue FOR EACH ROW
EXECUTE FUNCTION update_notification_queue_updated_at();