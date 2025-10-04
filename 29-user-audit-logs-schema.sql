-- User Audit Logs Schema
-- This table tracks user actions and system changes for auditing and compliance

CREATE TABLE public.user_audit_logs (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  user_id uuid NULL,
  target_user_id uuid NULL,
  action character varying(100) NOT NULL,
  table_name character varying(100) NULL,
  record_id uuid NULL,
  old_values jsonb NULL,
  new_values jsonb NULL,
  ip_address inet NULL,
  user_agent text NULL,
  performed_by uuid NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT user_audit_logs_pkey PRIMARY KEY (id),
  CONSTRAINT user_audit_logs_performed_by_fkey FOREIGN KEY (performed_by) REFERENCES users (id),
  CONSTRAINT user_audit_logs_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT user_audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_user_audit_logs_user_id ON public.user_audit_logs USING btree (user_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_action ON public.user_audit_logs USING btree (action) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_user_audit_logs_created_at ON public.user_audit_logs USING btree (created_at) TABLESPACE pg_default;