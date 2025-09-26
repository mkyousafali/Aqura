-- Create HR Employee Documents Table (Fixed Structure)
-- This matches the frontend dataService expectations exactly

-- Drop the existing table if it exists (be careful with data!)
-- DROP TABLE IF EXISTS public.hr_employee_documents;

-- Create the hr_employee_documents table with the correct structure
CREATE TABLE IF NOT EXISTS public.hr_employee_documents (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  employee_id uuid NOT NULL,
  document_type character varying(50) NOT NULL,
  document_name character varying(200) NOT NULL,
  file_path text NOT NULL,
  file_size bigint NULL,
  file_type character varying(50) NULL,
  expiry_date date NULL,
  upload_date date NOT NULL DEFAULT CURRENT_DATE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  CONSTRAINT hr_employee_documents_pkey PRIMARY KEY (id),
  CONSTRAINT hr_employee_documents_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_documents_employee_id ON public.hr_employee_documents USING btree (employee_id) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_hr_documents_type ON public.hr_employee_documents USING btree (document_type) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_hr_documents_expiry ON public.hr_employee_documents USING btree (expiry_date) TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_hr_documents_active ON public.hr_employee_documents USING btree (is_active) TABLESPACE pg_default;

-- Add RLS (Row Level Security) policies
ALTER TABLE public.hr_employee_documents ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users
CREATE POLICY IF NOT EXISTS "Enable read access for authenticated users" ON public.hr_employee_documents
FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Enable insert access for authenticated users" ON public.hr_employee_documents
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Enable update access for authenticated users" ON public.hr_employee_documents
FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY IF NOT EXISTS "Enable delete access for authenticated users" ON public.hr_employee_documents
FOR DELETE USING (auth.role() = 'authenticated');

-- Add table comment
COMMENT ON TABLE public.hr_employee_documents IS 'Stores employee documents including certificates, licenses, and other files with expiry tracking';

-- Add column comments for clarity
COMMENT ON COLUMN public.hr_employee_documents.id IS 'Unique identifier for the document record';
COMMENT ON COLUMN public.hr_employee_documents.employee_id IS 'Reference to the employee who owns this document';
COMMENT ON COLUMN public.hr_employee_documents.document_type IS 'Type of document (passport, visa, license, etc.)';
COMMENT ON COLUMN public.hr_employee_documents.document_name IS 'Display name for the document';
COMMENT ON COLUMN public.hr_employee_documents.file_path IS 'Storage path or URL to the actual file';
COMMENT ON COLUMN public.hr_employee_documents.file_size IS 'Size of the file in bytes';
COMMENT ON COLUMN public.hr_employee_documents.file_type IS 'MIME type of the file (application/pdf, image/jpeg, etc.)';
COMMENT ON COLUMN public.hr_employee_documents.expiry_date IS 'Date when the document expires (null if no expiry)';
COMMENT ON COLUMN public.hr_employee_documents.upload_date IS 'Date when the document was uploaded';
COMMENT ON COLUMN public.hr_employee_documents.is_active IS 'Whether the document record is active (soft delete flag)';
COMMENT ON COLUMN public.hr_employee_documents.created_at IS 'Timestamp when the record was created';
COMMENT ON COLUMN public.hr_employee_documents.updated_at IS 'Timestamp when the record was last updated';

-- Insert sample data for testing (only if no data exists)
-- This will create sample documents for the first 3 employees
INSERT INTO public.hr_employee_documents (employee_id, document_type, document_name, file_path, file_type, file_size, expiry_date)
SELECT 
  he.id,
  'passport',
  'Passport - ' || he.name,
  '/documents/employees/' || he.employee_id || '/passport.pdf',
  'application/pdf',
  1024000,
  CURRENT_DATE + INTERVAL '5 years'
FROM hr_employees he
WHERE NOT EXISTS (
  SELECT 1 FROM hr_employee_documents WHERE employee_id = he.id AND document_type = 'passport'
)
LIMIT 3;

-- Add driving license sample data
INSERT INTO public.hr_employee_documents (employee_id, document_type, document_name, file_path, file_type, file_size, expiry_date)
SELECT 
  he.id,
  'driving_license',
  'Driving License - ' || he.name,
  '/documents/employees/' || he.employee_id || '/driving_license.pdf',
  'application/pdf',
  512000,
  CURRENT_DATE + INTERVAL '2 years'
FROM hr_employees he
WHERE NOT EXISTS (
  SELECT 1 FROM hr_employee_documents WHERE employee_id = he.id AND document_type = 'driving_license'
)
LIMIT 2;

-- Add degree certificate (no expiry)
INSERT INTO public.hr_employee_documents (employee_id, document_type, document_name, file_path, file_type, file_size, expiry_date)
SELECT 
  he.id,
  'degree_certificate',
  'Bachelor Degree - ' || he.name,
  '/documents/employees/' || he.employee_id || '/degree.pdf',
  'application/pdf',
  2048000,
  NULL
FROM hr_employees he
WHERE NOT EXISTS (
  SELECT 1 FROM hr_employee_documents WHERE employee_id = he.id AND document_type = 'degree_certificate'
)
LIMIT 2;

-- Success message
SELECT 'HR Employee Documents table created successfully with sample data!' as result;