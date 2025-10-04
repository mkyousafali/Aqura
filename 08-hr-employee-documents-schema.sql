-- HR Employee Documents Schema
-- Manages employee document storage and tracking with expiry dates

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
  CONSTRAINT hr_employee_documents_pkey PRIMARY KEY (id),
  CONSTRAINT hr_employee_documents_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_hr_documents_employee_id ON public.hr_employee_documents USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_type ON public.hr_employee_documents USING btree (document_type) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_expiry ON public.hr_employee_documents USING btree (expiry_date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_active ON public.hr_employee_documents USING btree (is_active) TABLESPACE pg_default;