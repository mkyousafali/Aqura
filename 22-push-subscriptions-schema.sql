-- Push Subscriptions Schema
-- This table manages push notification subscriptions for users across different devices

CREATE TABLE public.push_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  device_id character varying(100) NOT NULL,
  endpoint text NOT NULL,
  p256dh text NOT NULL,
  auth text NOT NULL,
  device_type character varying(20) NOT NULL,
  browser_name character varying(50) NULL,
  user_agent text NULL,
  is_active boolean NULL DEFAULT true,
  last_seen timestamp with time zone NULL DEFAULT now(),
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT push_subscriptions_user_id_device_id_key UNIQUE (user_id, device_id),
  CONSTRAINT push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT push_subscriptions_device_type_check CHECK (
    (device_type)::text = ANY (
      (
        ARRAY[
          'mobile'::character varying,
          'desktop'::character varying
        ]
      )::text[]
    )
  )
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_user_id ON public.push_subscriptions USING btree (user_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_device_id ON public.push_subscriptions USING btree (device_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_active ON public.push_subscriptions USING btree (is_active) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_last_seen ON public.push_subscriptions USING btree (last_seen) TABLESPACE pg_default;

-- Triggers to update the updated_at timestamp
CREATE TRIGGER trigger_push_subscriptions_updated_at BEFORE UPDATE ON push_subscriptions FOR EACH ROW
EXECUTE FUNCTION update_push_subscriptions_updated_at();

CREATE TRIGGER trigger_update_push_subscriptions_updated_at BEFORE UPDATE ON push_subscriptions FOR EACH ROW
EXECUTE FUNCTION update_push_subscriptions_updated_at();