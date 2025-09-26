-- HR Employee Documents Table
-- This creates the table for managing employee documents with file storage and expiry tracking

-- Create the hr_employee_documents table
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

-- Add RLS (Row Level Security) policies if needed
ALTER TABLE public.hr_employee_documents ENABLE ROW LEVEL SECURITY;

-- Create policy for authenticated users to see documents
CREATE POLICY IF NOT EXISTS "Enable read access for authenticated users" ON public.hr_employee_documents
FOR SELECT USING (auth.role() = 'authenticated');

-- Create policy for authenticated users to insert documents
CREATE POLICY IF NOT EXISTS "Enable insert access for authenticated users" ON public.hr_employee_documents
FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Create policy for authenticated users to update documents
CREATE POLICY IF NOT EXISTS "Enable update access for authenticated users" ON public.hr_employee_documents
FOR UPDATE USING (auth.role() = 'authenticated');

-- Create policy for authenticated users to delete documents
CREATE POLICY IF NOT EXISTS "Enable delete access for authenticated users" ON public.hr_employee_documents
FOR DELETE USING (auth.role() = 'authenticated');

-- Insert some sample data for testing (optional)
-- This will only run if there's no existing data
INSERT INTO public.hr_employee_documents (employee_id, document_type, document_name, file_path, file_type, file_size, expiry_date)
SELECT 
  he.id,
  'passport',
  'Passport - ' || he.name,
  '/documents/passports/' || he.employee_id || '_passport.pdf',
  'application/pdf',
  1024000,
  CURRENT_DATE + INTERVAL '5 years'
FROM hr_employees he
WHERE NOT EXISTS (SELECT 1 FROM hr_employee_documents WHERE employee_id = he.id)
LIMIT 5;

-- Add comment to table
COMMENT ON TABLE public.hr_employee_documents IS 'Stores employee documents including certificates, licenses, and other files with expiry tracking';