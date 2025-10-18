-- Add document_description field to hr_employee_documents table
-- This field will store document descriptions and additional details

-- Add the document_description column
ALTER TABLE public.hr_employee_documents 
ADD COLUMN IF NOT EXISTS document_description TEXT NULL;

-- Add comment for the new column
COMMENT ON COLUMN public.hr_employee_documents.document_description IS 'Additional description or details about the document';

-- Add success notice
DO $$ 
BEGIN 
    RAISE NOTICE 'Added document_description field to hr_employee_documents table';
END $$;