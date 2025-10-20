-- Migration: Create app_functions table
-- File: 1_app_functions.sql
-- Description: Creates the app_functions table for managing application functions with codes and descriptions

BEGIN;

-- Create the update_updated_at_column function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create app_functions table
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

-- Create index for active functions
CREATE INDEX IF NOT EXISTS idx_app_functions_active 
ON public.app_functions USING btree (function_code) 
TABLESPACE pg_default
WHERE (is_active = true);

-- Create trigger for updating updated_at column
CREATE TRIGGER update_app_functions_updated_at 
BEFORE UPDATE ON app_functions 
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

COMMIT;