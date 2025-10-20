-- Migration: Create branches table
-- File: 2_branches.sql
-- Description: Creates the branches table for managing company branches with bilingual support

BEGIN;

-- Create the update function for branches
CREATE OR REPLACE FUNCTION update_branches_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create branches table
CREATE TABLE public.branches (
  id bigserial NOT NULL,
  name_en character varying(255) NOT NULL,
  name_ar character varying(255) NOT NULL,
  location_en character varying(500) NOT NULL,
  location_ar character varying(500) NOT NULL,
  is_active boolean NULL DEFAULT true,
  is_main_branch boolean NULL DEFAULT false,
  created_at timestamp with time zone NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  created_by bigint NULL,
  updated_by bigint NULL,
  vat_number character varying(50) NULL,
  CONSTRAINT branches_pkey PRIMARY KEY (id),
  CONSTRAINT check_vat_number_not_empty CHECK (
    (
      (vat_number IS NULL)
      OR (
        length(
          TRIM(
            both
            FROM
              vat_number
          )
        ) > 0
      )
    )
  )
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_branches_name_en 
ON public.branches USING btree (name_en) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_name_ar 
ON public.branches USING btree (name_ar) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_active 
ON public.branches USING btree (is_active) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_main 
ON public.branches USING btree (is_main_branch) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_branches_vat_number 
ON public.branches USING btree (vat_number) 
TABLESPACE pg_default
WHERE (vat_number IS NOT NULL);

-- Create trigger for updating updated_at column
CREATE TRIGGER trigger_update_branches_updated_at 
BEFORE UPDATE ON branches 
FOR EACH ROW
EXECUTE FUNCTION update_branches_updated_at();

COMMIT;