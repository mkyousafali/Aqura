-- Migration: Create user_device_sessions table
-- File: 38_user_device_sessions.sql
-- Description: Creates the user_device_sessions table for managing user device sessions and authentication

BEGIN;

-- Create user_device_sessions table
CREATE TABLE public.user_device_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  device_id character varying(100) NOT NULL,
  session_token character varying(255) NOT NULL,
  device_type character varying(20) NOT NULL,
  browser_name character varying(50) NULL,
  user_agent text NULL,
  ip_address inet NULL,
  is_active boolean NULL DEFAULT true,
  login_at timestamp with time zone NULL DEFAULT now(),
  last_activity timestamp with time zone NULL DEFAULT now(),
  expires_at timestamp with time zone NULL DEFAULT (now() + '24:00:00'::interval),
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT user_device_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT user_device_sessions_user_id_device_id_key UNIQUE (user_id, device_id),
  CONSTRAINT user_device_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT user_device_sessions_device_type_check CHECK (
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

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_user_device_sessions_user_id 
ON public.user_device_sessions USING btree (user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_device_id 
ON public.user_device_sessions USING btree (device_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_active 
ON public.user_device_sessions USING btree (is_active) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_expires_at 
ON public.user_device_sessions USING btree (expires_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_device_sessions_last_activity 
ON public.user_device_sessions USING btree (last_activity) 
TABLESPACE pg_default;

-- Create trigger
CREATE TRIGGER trigger_user_device_sessions_updated_at 
BEFORE UPDATE ON user_device_sessions 
FOR EACH ROW
EXECUTE FUNCTION update_user_device_sessions_updated_at();

COMMIT;