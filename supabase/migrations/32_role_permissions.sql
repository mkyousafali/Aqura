-- Migration: Create role_permissions table
-- File: 32_role_permissions.sql
-- Description: Creates the role_permissions table for managing role-based permissions on app functions

BEGIN;

-- Create role_permissions table
CREATE TABLE public.role_permissions (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  role_id uuid NOT NULL,
  function_id uuid NOT NULL,
  can_view boolean NULL DEFAULT false,
  can_add boolean NULL DEFAULT false,
  can_edit boolean NULL DEFAULT false,
  can_delete boolean NULL DEFAULT false,
  can_export boolean NULL DEFAULT false,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT role_permissions_pkey PRIMARY KEY (id),
  CONSTRAINT role_permissions_role_id_function_id_key UNIQUE (role_id, function_id),
  CONSTRAINT role_permissions_function_id_fkey FOREIGN KEY (function_id) REFERENCES app_functions (id) ON DELETE CASCADE,
  CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES user_roles (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_role_permissions_role_id 
ON public.role_permissions USING btree (role_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_role_permissions_function_id 
ON public.role_permissions USING btree (function_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_role_permissions_composite 
ON public.role_permissions USING btree (role_id, function_id) 
TABLESPACE pg_default;

-- Create trigger
CREATE TRIGGER update_role_permissions_updated_at 
BEFORE UPDATE ON role_permissions 
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMIT;