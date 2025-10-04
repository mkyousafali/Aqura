-- User Sessions Schema
-- This table manages user authentication sessions with login method tracking

CREATE TABLE public.user_sessions (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  session_token character varying(255) NOT NULL,
  login_method character varying(20) NOT NULL,
  ip_address inet NULL,
  user_agent text NULL,
  is_active boolean NULL DEFAULT true,
  expires_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  ended_at timestamp with time zone NULL,
  CONSTRAINT user_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT user_sessions_session_token_key UNIQUE (session_token),
  CONSTRAINT user_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT user_sessions_login_method_check CHECK (
    (login_method)::text = ANY (
      (
        ARRAY[
          'quick_access'::character varying,
          'username_password'::character varying
        ]
      )::text[]
    )
  )
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON public.user_sessions USING btree (user_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON public.user_sessions USING btree (session_token) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_sessions_active ON public.user_sessions USING btree (is_active) TABLESPACE pg_default;