-- Users Schema
-- This table manages user accounts with comprehensive authentication and authorization features

CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  username character varying(50) NOT NULL,
  password_hash character varying(255) NOT NULL,
  salt character varying(100) NOT NULL,
  quick_access_code character varying(6) NOT NULL,
  quick_access_salt character varying(100) NOT NULL,
  user_type public.user_type_enum NOT NULL DEFAULT 'branch_specific'::user_type_enum,
  employee_id uuid NULL,
  branch_id bigint NULL,
  role_type public.role_type_enum NULL DEFAULT 'Position-based'::role_type_enum,
  position_id uuid NULL,
  avatar text NULL,
  avatar_small_url text NULL,
  avatar_medium_url text NULL,
  avatar_large_url text NULL,
  status public.user_status_enum NULL DEFAULT 'active'::user_status_enum,
  is_first_login boolean NULL DEFAULT true,
  failed_login_attempts integer NULL DEFAULT 0,
  locked_at timestamp with time zone NULL,
  locked_by uuid NULL,
  last_login_at timestamp with time zone NULL,
  password_expires_at timestamp with time zone NULL,
  last_password_change timestamp with time zone NULL DEFAULT now(),
  created_by bigint NULL,
  updated_by bigint NULL,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT users_pkey PRIMARY KEY (id),
  CONSTRAINT users_username_key UNIQUE (username),
  CONSTRAINT users_quick_access_code_key UNIQUE (quick_access_code),
  CONSTRAINT users_locked_by_fkey FOREIGN KEY (locked_by) REFERENCES users (id),
  CONSTRAINT users_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE SET NULL,
  CONSTRAINT users_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id) ON DELETE SET NULL,
  CONSTRAINT users_employee_branch_check CHECK (
    (user_type = 'global'::user_type_enum)
    OR (
      (user_type = 'branch_specific'::user_type_enum)
      AND (branch_id IS NOT NULL)
    )
  ),
  CONSTRAINT users_quick_access_length CHECK ((length((quick_access_code)::text) = 6)),
  CONSTRAINT users_quick_access_numeric CHECK (((quick_access_code)::text ~ '^[0-9]{6}$'::text))
) TABLESPACE pg_default;

-- Indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_users_username ON public.users USING btree (username) TABLESPACE pg_default;

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_quick_access ON public.users USING btree (quick_access_code) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_status ON public.users USING btree (status) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_role_type ON public.users USING btree (role_type) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_employee_id ON public.users USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_branch_id ON public.users USING btree (branch_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_created_at ON public.users USING btree (created_at) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_users_last_login ON public.users USING btree (last_login_at) TABLESPACE pg_default;

-- Triggers for automated functionality
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER users_audit_trigger
AFTER INSERT
OR DELETE
OR UPDATE ON users FOR EACH ROW
EXECUTE FUNCTION log_user_action();