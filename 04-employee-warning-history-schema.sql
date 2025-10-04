-- Employee Warning History Schema
-- Tracks all changes and actions performed on employee warnings

CREATE TABLE public.employee_warning_history (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  warning_id uuid NOT NULL,
  action_type character varying(20) NOT NULL,
  old_values jsonb NULL,
  new_values jsonb NULL,
  changed_by uuid NULL,
  changed_by_username character varying(255) NULL,
  change_reason text NULL,
  created_at timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ip_address inet NULL,
  user_agent text NULL,
  CONSTRAINT employee_warning_history_pkey PRIMARY KEY (id),
  CONSTRAINT employee_warning_history_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT employee_warning_history_warning_id_fkey FOREIGN KEY (warning_id) REFERENCES employee_warnings (id) ON DELETE CASCADE,
  CONSTRAINT employee_warning_history_action_type_check CHECK (
    (action_type)::text = ANY (
      (
        ARRAY[
          'created'::character varying,
          'updated'::character varying,
          'deleted'::character varying,
          'status_changed'::character varying,
          'fine_paid'::character varying,
          'acknowledged'::character varying,
          'resolved'::character varying
        ]
      )::text[]
    )
  )
) TABLESPACE pg_default;

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_employee_warning_history_warning_id ON public.employee_warning_history USING btree (warning_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_action_type ON public.employee_warning_history USING btree (action_type) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_changed_by ON public.employee_warning_history USING btree (changed_by) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_employee_warning_history_created_at ON public.employee_warning_history USING btree (created_at) TABLESPACE pg_default;