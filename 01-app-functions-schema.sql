-- Table 1: App Functions
-- Purpose: Manages application functions and their metadata
-- Created: 2025-09-29

CREATE TABLE public.app_functions (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  function_name character varying(100) NOT NULL,
  function_code character varying(50) NOT NULL,
  description text NULL,
  category character varying(50) NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT app_functions_pkey PRIMARY KEY (id),
  CONSTRAINT app_functions_function_code_key UNIQUE (function_code),
  CONSTRAINT app_functions_function_name_key UNIQUE (function_name)
) TABLESPACE pg_default;

-- Trigger to automatically update the updated_at column
CREATE TRIGGER update_app_functions_updated_at 
  BEFORE UPDATE ON app_functions 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Comments for documentation
COMMENT ON TABLE public.app_functions IS 'Stores application functions and their metadata for system functionality management';
COMMENT ON COLUMN public.app_functions.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.app_functions.function_name IS 'Human-readable name of the function (unique)';
COMMENT ON COLUMN public.app_functions.function_code IS 'Unique code identifier for the function';
COMMENT ON COLUMN public.app_functions.description IS 'Optional description of what the function does';
COMMENT ON COLUMN public.app_functions.category IS 'Optional category grouping for functions';
COMMENT ON COLUMN public.app_functions.is_active IS 'Whether the function is currently active/enabled';
COMMENT ON COLUMN public.app_functions.created_at IS 'Timestamp when the record was created';
COMMENT ON COLUMN public.app_functions.updated_at IS 'Timestamp when the record was last updated';