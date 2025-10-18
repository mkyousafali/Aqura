-- Add document_number field to hr_employee_documents table
-- This field will store document reference numbers, IDs, or serial numbers

-- Add the document_number column
ALTER TABLE public.hr_employee_documents 
ADD COLUMN IF NOT EXISTS document_number CHARACTER VARYING(100) NULL;

-- Add index for document number searches
CREATE INDEX IF NOT EXISTS idx_hr_documents_document_number 
ON public.hr_employee_documents USING btree (document_number) 
WHERE document_number IS NOT NULL;

-- Add comment for the new column
COMMENT ON COLUMN public.hr_employee_documents.document_number IS 'Document reference number, ID, or serial number';

-- Add success notice
DO $$ 
BEGIN 
    RAISE NOTICE 'Added document_number field to hr_employee_documents table';
END $$;