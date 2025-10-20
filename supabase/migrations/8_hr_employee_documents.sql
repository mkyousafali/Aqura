-- Migration: Create hr_employee_documents table
-- File: 8_hr_employee_documents.sql
-- Description: Creates the hr_employee_documents table for managing employee documents with categories and expiry tracking

BEGIN;

-- Create document category enum type
CREATE TYPE public.document_category_enum AS ENUM (
    'health_card',
    'resident_id',
    'passport',
    'driving_license',
    'resume',
    'sick_leave',
    'special_leave',
    'annual_leave',
    'resignation',
    'other'
);

-- Create trigger functions
CREATE OR REPLACE FUNCTION calculate_category_days()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.category_start_date IS NOT NULL AND NEW.category_end_date IS NOT NULL THEN
        NEW.category_days := NEW.category_end_date - NEW.category_start_date + 1;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION clear_main_document_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION handle_document_deactivation()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_main_document_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- This function will be implemented when needed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create hr_employee_documents table
CREATE TABLE public.hr_employee_documents (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  employee_id uuid NOT NULL,
  document_type character varying(50) NOT NULL,
  document_name character varying(200) NOT NULL,
  file_path text NOT NULL,
  file_type character varying(50) NULL,
  expiry_date date NULL,
  upload_date date NOT NULL DEFAULT CURRENT_DATE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  document_number character varying(100) NULL,
  document_description text NULL,
  health_card_number character varying(100) NULL,
  health_card_expiry date NULL,
  resident_id_number character varying(100) NULL,
  resident_id_expiry date NULL,
  passport_number character varying(100) NULL,
  passport_expiry date NULL,
  driving_license_number character varying(100) NULL,
  driving_license_expiry date NULL,
  resume_uploaded boolean NULL DEFAULT false,
  document_category public.document_category_enum NULL DEFAULT 'other'::document_category_enum,
  category_start_date date NULL,
  category_end_date date NULL,
  category_days integer NULL,
  category_last_working_day date NULL,
  category_reason text NULL,
  category_details text NULL,
  category_content text NULL,
  CONSTRAINT hr_employee_documents_pkey PRIMARY KEY (id),
  CONSTRAINT hr_employee_documents_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id) ON DELETE CASCADE,
  CONSTRAINT check_leave_dates CHECK (
    (
      (
        document_category <> ALL (
          ARRAY[
            'sick_leave'::document_category_enum,
            'special_leave'::document_category_enum,
            'annual_leave'::document_category_enum
          ]
        )
      )
      OR (
        (category_start_date IS NULL)
        OR (category_end_date IS NULL)
        OR (category_start_date <= category_end_date)
      )
    )
  ),
  CONSTRAINT check_resignation_last_working_day CHECK (
    (
      (
        document_category <> 'resignation'::document_category_enum
      )
      OR (category_last_working_day IS NOT NULL)
    )
  )
) TABLESPACE pg_default;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_hr_documents_document_number 
ON public.hr_employee_documents USING btree (document_number) 
TABLESPACE pg_default
WHERE (document_number IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_hr_documents_employee_id 
ON public.hr_employee_documents USING btree (employee_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_type 
ON public.hr_employee_documents USING btree (document_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_expiry 
ON public.hr_employee_documents USING btree (expiry_date) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_active 
ON public.hr_employee_documents USING btree (is_active) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_health_card_number 
ON public.hr_employee_documents USING btree (health_card_number) 
TABLESPACE pg_default
WHERE (health_card_number IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_hr_documents_resident_id_number 
ON public.hr_employee_documents USING btree (resident_id_number) 
TABLESPACE pg_default
WHERE (resident_id_number IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_hr_documents_passport_number 
ON public.hr_employee_documents USING btree (passport_number) 
TABLESPACE pg_default
WHERE (passport_number IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_hr_documents_driving_license_number 
ON public.hr_employee_documents USING btree (driving_license_number) 
TABLESPACE pg_default
WHERE (driving_license_number IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_hr_documents_health_card_expiry 
ON public.hr_employee_documents USING btree (health_card_expiry) 
TABLESPACE pg_default
WHERE (health_card_expiry IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_hr_documents_resident_id_expiry 
ON public.hr_employee_documents USING btree (resident_id_expiry) 
TABLESPACE pg_default
WHERE (resident_id_expiry IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_hr_documents_passport_expiry 
ON public.hr_employee_documents USING btree (passport_expiry) 
TABLESPACE pg_default
WHERE (passport_expiry IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_hr_documents_driving_license_expiry 
ON public.hr_employee_documents USING btree (driving_license_expiry) 
TABLESPACE pg_default
WHERE (driving_license_expiry IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_category 
ON public.hr_employee_documents USING btree (document_category) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_category_dates 
ON public.hr_employee_documents USING btree (
  document_category,
  category_start_date,
  category_end_date
) TABLESPACE pg_default
WHERE (category_start_date IS NOT NULL);

-- Create triggers
CREATE TRIGGER trigger_calculate_category_days 
BEFORE INSERT OR UPDATE ON hr_employee_documents 
FOR EACH ROW
EXECUTE FUNCTION calculate_category_days();

CREATE TRIGGER trigger_clear_main_document_columns 
BEFORE DELETE ON hr_employee_documents 
FOR EACH ROW
EXECUTE FUNCTION clear_main_document_columns();

CREATE TRIGGER trigger_handle_document_deactivation 
BEFORE UPDATE ON hr_employee_documents 
FOR EACH ROW
EXECUTE FUNCTION handle_document_deactivation();

CREATE TRIGGER trigger_update_main_document_columns 
BEFORE INSERT OR UPDATE ON hr_employee_documents 
FOR EACH ROW
EXECUTE FUNCTION update_main_document_columns();

COMMIT;