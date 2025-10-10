-- Create hr_employee_documents table for managing employee document records
-- This table stores document information and file references for employees

-- Create the hr_employee_documents table
CREATE TABLE IF NOT EXISTS public.hr_employee_documents (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    employee_id UUID NOT NULL,
    document_type CHARACTER VARYING(50) NOT NULL,
    document_name CHARACTER VARYING(200) NOT NULL,
    file_path TEXT NOT NULL,
    file_type CHARACTER VARYING(50) NULL,
    expiry_date DATE NULL,
    upload_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT hr_employee_documents_pkey PRIMARY KEY (id),
    CONSTRAINT hr_employee_documents_employee_id_fkey 
        FOREIGN KEY (employee_id) REFERENCES hr_employees (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for efficient queries
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

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_hr_documents_employee_type 
ON public.hr_employee_documents (employee_id, document_type) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_hr_documents_expiring_soon 
ON public.hr_employee_documents (expiry_date) 
WHERE expiry_date IS NOT NULL AND expiry_date > CURRENT_DATE AND is_active = true;

CREATE INDEX IF NOT EXISTS idx_hr_documents_expired 
ON public.hr_employee_documents (expiry_date) 
WHERE expiry_date IS NOT NULL AND expiry_date <= CURRENT_DATE AND is_active = true;

CREATE INDEX IF NOT EXISTS idx_hr_documents_upload_date 
ON public.hr_employee_documents (upload_date DESC);

CREATE INDEX IF NOT EXISTS idx_hr_documents_file_type 
ON public.hr_employee_documents (file_type) 
WHERE file_type IS NOT NULL;

-- Create text search index for document names
CREATE INDEX IF NOT EXISTS idx_hr_documents_name_search 
ON public.hr_employee_documents USING gin (to_tsvector('english', document_name));

-- Create trigger for updated_at timestamp
CREATE OR REPLACE FUNCTION update_hr_employee_documents_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_employee_documents_updated_at 
BEFORE UPDATE ON hr_employee_documents 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_employee_documents_updated_at();

-- Add data validation constraints
ALTER TABLE public.hr_employee_documents 
ADD CONSTRAINT chk_document_name_not_empty 
CHECK (TRIM(document_name) != '');

ALTER TABLE public.hr_employee_documents 
ADD CONSTRAINT chk_file_path_not_empty 
CHECK (TRIM(file_path) != '');

ALTER TABLE public.hr_employee_documents 
ADD CONSTRAINT chk_document_type_not_empty 
CHECK (TRIM(document_type) != '');

ALTER TABLE public.hr_employee_documents 
ADD CONSTRAINT chk_expiry_date_future 
CHECK (expiry_date IS NULL OR expiry_date >= upload_date);

-- Add common document types constraint
ALTER TABLE public.hr_employee_documents 
ADD CONSTRAINT chk_document_type_valid 
CHECK (document_type IN (
    'passport', 'national_id', 'visa', 'work_permit', 'driving_license',
    'contract', 'resume', 'certificate', 'diploma', 'transcript',
    'medical_certificate', 'insurance', 'emergency_contact', 'bank_details',
    'photo', 'other'
));

-- Add file type validation
ALTER TABLE public.hr_employee_documents 
ADD CONSTRAINT chk_file_type_valid 
CHECK (file_type IS NULL OR file_type IN (
    'pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'gif', 'tiff',
    'xls', 'xlsx', 'txt', 'rtf', 'odt', 'ods', 'odp'
));

-- Create unique constraint for active documents of same type per employee
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_documents_unique_active_type 
ON public.hr_employee_documents (employee_id, document_type) 
WHERE is_active = true AND document_type IN ('passport', 'national_id', 'contract');

-- Add table and column comments
COMMENT ON TABLE public.hr_employee_documents IS 'Document management system for HR employees';
COMMENT ON COLUMN public.hr_employee_documents.id IS 'Unique identifier for the document record';
COMMENT ON COLUMN public.hr_employee_documents.employee_id IS 'Reference to the employee';
COMMENT ON COLUMN public.hr_employee_documents.document_type IS 'Type/category of the document';
COMMENT ON COLUMN public.hr_employee_documents.document_name IS 'Display name of the document';
COMMENT ON COLUMN public.hr_employee_documents.file_path IS 'Storage path or URL of the document file';
COMMENT ON COLUMN public.hr_employee_documents.file_type IS 'File extension or MIME type';
COMMENT ON COLUMN public.hr_employee_documents.expiry_date IS 'Document expiration date if applicable';
COMMENT ON COLUMN public.hr_employee_documents.upload_date IS 'Date when document was uploaded';
COMMENT ON COLUMN public.hr_employee_documents.is_active IS 'Whether the document is currently active';
COMMENT ON COLUMN public.hr_employee_documents.created_at IS 'Timestamp when the record was created';
COMMENT ON COLUMN public.hr_employee_documents.updated_at IS 'Timestamp when the record was last updated';

-- Create view for active documents
CREATE OR REPLACE VIEW active_employee_documents AS
SELECT 
    d.id,
    d.employee_id,
    d.document_type,
    d.document_name,
    d.file_path,
    d.file_type,
    d.expiry_date,
    d.upload_date,
    d.created_at,
    d.updated_at,
    CASE 
        WHEN d.expiry_date IS NULL THEN 'no_expiry'
        WHEN d.expiry_date <= CURRENT_DATE THEN 'expired'
        WHEN d.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'expiring_soon'
        ELSE 'valid'
    END as expiry_status
FROM hr_employee_documents d
WHERE d.is_active = true;

-- Create function to check expiring documents
CREATE OR REPLACE FUNCTION get_expiring_documents(days_ahead INTEGER DEFAULT 30)
RETURNS TABLE(
    employee_id UUID,
    document_type VARCHAR,
    document_name VARCHAR,
    expiry_date DATE,
    days_until_expiry INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.employee_id,
        d.document_type,
        d.document_name,
        d.expiry_date,
        (d.expiry_date - CURRENT_DATE)::INTEGER as days_until_expiry
    FROM hr_employee_documents d
    WHERE d.is_active = true 
      AND d.expiry_date IS NOT NULL
      AND d.expiry_date BETWEEN CURRENT_DATE AND CURRENT_DATE + days_ahead
    ORDER BY d.expiry_date ASC;
END;
$$ LANGUAGE plpgsql;

-- Create function to get document history for an employee
CREATE OR REPLACE FUNCTION get_employee_document_history(emp_id UUID, doc_type VARCHAR DEFAULT NULL)
RETURNS TABLE(
    document_id UUID,
    document_type VARCHAR,
    document_name VARCHAR,
    upload_date DATE,
    expiry_date DATE,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.id,
        d.document_type,
        d.document_name,
        d.upload_date,
        d.expiry_date,
        d.is_active,
        d.created_at
    FROM hr_employee_documents d
    WHERE d.employee_id = emp_id
      AND (doc_type IS NULL OR d.document_type = doc_type)
    ORDER BY d.document_type, d.created_at DESC;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'hr_employee_documents table created with document management features';