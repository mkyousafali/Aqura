-- Migration: Create hr_positions table
-- File: 14_hr_positions.sql
-- Description: Creates the hr_positions table for managing job positions with bilingual support

BEGIN;

-- Create trigger function for syncing user roles
CREATE OR REPLACE FUNCTION sync_user_roles_from_positions()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Create hr_positions table
CREATE TABLE public.hr_positions (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  position_title_en character varying(100) NOT NULL,
  position_title_ar character varying(100) NOT NULL,
  department_id uuid NOT NULL,
  level_id uuid NOT NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_positions_pkey PRIMARY KEY (id),
  CONSTRAINT hr_positions_department_id_fkey FOREIGN KEY (department_id) REFERENCES hr_departments (id),
  CONSTRAINT hr_positions_level_id_fkey FOREIGN KEY (level_id) REFERENCES hr_levels (id)
) TABLESPACE pg_default;

-- Create trigger
CREATE TRIGGER sync_roles_on_position_changes
AFTER INSERT OR DELETE OR UPDATE ON hr_positions 
FOR EACH ROW
EXECUTE FUNCTION sync_user_roles_from_positions();

COMMIT;