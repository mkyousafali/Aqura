-- Table 5: HR Employee Documents
-- Purpose: Manages employee document uploads and metadata with expiry tracking
-- Created: 2025-09-29

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

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_documents_employee_id 
  ON public.hr_employee_documents USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_type 
  ON public.hr_employee_documents USING btree (document_type) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_expiry 
  ON public.hr_employee_documents USING btree (expiry_date) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_active 
  ON public.hr_employee_documents USING btree (is_active) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_documents_upload_date 
  ON public.hr_employee_documents USING btree (upload_date) TABLESPACE pg_default;

-- Trigger to automatically update the updated_at column
CREATE TRIGGER trigger_update_hr_employee_documents_updated_at 
  BEFORE UPDATE ON hr_employee_documents 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Comments for documentation
COMMENT ON TABLE public.hr_employee_documents IS 'Employee document management with file storage and expiry tracking';
COMMENT ON COLUMN public.hr_employee_documents.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_employee_documents.employee_id IS 'Foreign key reference to hr_employees table (required, cascading delete)';
COMMENT ON COLUMN public.hr_employee_documents.document_type IS 'Type/category of document (e.g., passport, visa, contract)';
COMMENT ON COLUMN public.hr_employee_documents.document_name IS 'Human-readable name/title of the document';
COMMENT ON COLUMN public.hr_employee_documents.file_path IS 'Full path to the uploaded document file';
COMMENT ON COLUMN public.hr_employee_documents.file_type IS 'File extension or MIME type (e.g., pdf, jpg, png)';
COMMENT ON COLUMN public.hr_employee_documents.expiry_date IS 'Optional expiry date for documents that expire';
COMMENT ON COLUMN public.hr_employee_documents.upload_date IS 'Date when the document was uploaded (auto-set)';
COMMENT ON COLUMN public.hr_employee_documents.is_active IS 'Whether the document is currently active/valid';
COMMENT ON COLUMN public.hr_employee_documents.created_at IS 'Timestamp when the record was created';
COMMENT ON COLUMN public.hr_employee_documents.updated_at IS 'Timestamp when the record was last updated';