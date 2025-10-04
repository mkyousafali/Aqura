-- User Password History Schema
-- This table stores password history for users to prevent password reuse

CREATE TABLE public.user_password_history (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NOT NULL,
  password_hash character varying(255) NOT NULL,
  salt character varying(100) NOT NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT user_password_history_pkey PRIMARY KEY (id),
  CONSTRAINT user_password_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_password_history_user_created ON public.user_password_history USING btree (user_id, created_at DESC) TABLESPACE pg_default;