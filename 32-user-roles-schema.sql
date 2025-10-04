-- User Roles Schema
-- This table manages user roles with system and custom role support

CREATE TABLE public.user_roles (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  role_name character varying(100) NOT NULL,
  role_code character varying(50) NOT NULL,
  description text NULL,
  is_system_role boolean NULL DEFAULT false,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  created_by uuid NULL,
  updated_by uuid NULL,
  CONSTRAINT user_roles_pkey PRIMARY KEY (id),
  CONSTRAINT user_roles_role_code_key UNIQUE (role_code),
  CONSTRAINT user_roles_role_name_key UNIQUE (role_name)
) TABLESPACE pg_default;

-- Trigger to update the updated_at timestamp
CREATE TRIGGER update_user_roles_updated_at BEFORE UPDATE ON user_roles FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();