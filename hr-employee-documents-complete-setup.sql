-- =====================================================
-- HR EMPLOYEE DOCUMENTS - COMPLETE SETUP WITH SUPABASE STORAGE
-- This includes table schema + storage bucket + policies
-- =====================================================

-- =====================================================
-- 1. CREATE HR EMPLOYEE DOCUMENTS TABLE (FIXED SCHEMA)
-- =====================================================

-- Drop existing table if needed (BE CAREFUL WITH EXISTING DATA!)
-- DROP TABLE IF EXISTS public.hr_employee_documents;

CREATE TABLE IF NOT EXISTS public.hr_employee_documents (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  employee_id uuid NOT NULL,
  document_type character varying(50) NOT NULL,
  document_name character varying(200) NOT NULL,
  file_path text NOT NULL, -- This will store the Supabase Storage public URL
  file_type character varying(50) NULL,
  expiry_date date NULL,
  upload_date date NOT NULL DEFAULT CURRENT_DATE,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NULL DEFAULT now(),
  
  CONSTRAINT hr_employee_documents_pkey PRIMARY KEY (id),
  CONSTRAINT hr_employee_documents_employee_id_fkey FOREIGN KEY (employee_id) 
    REFERENCES hr_employees (id) ON DELETE CASCADE
) TABLESPACE pg_default;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_documents_employee_id ON public.hr_employee_documents USING btree (employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_documents_type ON public.hr_employee_documents USING btree (document_type);
CREATE INDEX IF NOT EXISTS idx_hr_documents_expiry ON public.hr_employee_documents USING btree (expiry_date);
CREATE INDEX IF NOT EXISTS idx_hr_documents_active ON public.hr_employee_documents USING btree (is_active);

-- Add table and column comments
COMMENT ON TABLE public.hr_employee_documents IS 'Stores employee documents metadata with files in Supabase Storage';
COMMENT ON COLUMN public.hr_employee_documents.file_path IS 'Public URL from Supabase Storage bucket';
COMMENT ON COLUMN public.hr_employee_documents.document_type IS 'health_card, resident_id, passport, resume, other_1, other_2, other_3, other_4';

-- Add file_type column if it doesn't exist (for existing tables)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'hr_employee_documents' 
                   AND column_name = 'file_type') THEN
        ALTER TABLE public.hr_employee_documents ADD COLUMN file_type character varying(50) NULL;
    END IF;
END $$;

-- =====================================================
-- 2. CREATE STORAGE BUCKET (RUN IN SUPABASE SQL EDITOR)
-- =====================================================

-- Create the storage bucket for employee documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'employee-documents',
  'employee-documents', 
  true, -- Make bucket public so files can be accessed via URL
  10485760, -- 10MB file size limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
) ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 3. STORAGE POLICIES (RUN IN SUPABASE SQL EDITOR)
-- =====================================================

-- Drop existing storage policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users to upload employee documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to view employee documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to update employee documents" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to delete employee documents" ON storage.objects;

-- Policy to allow authenticated users to upload files
CREATE POLICY "Allow authenticated users to upload employee documents" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'employee-documents' AND
  auth.role() = 'authenticated'
);

-- Policy to allow authenticated users to view/download files
CREATE POLICY "Allow authenticated users to view employee documents" ON storage.objects
FOR SELECT USING (
  bucket_id = 'employee-documents' AND
  auth.role() = 'authenticated'
);

-- Policy to allow authenticated users to update files
CREATE POLICY "Allow authenticated users to update employee documents" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'employee-documents' AND
  auth.role() = 'authenticated'
);

-- Policy to allow authenticated users to delete files
CREATE POLICY "Allow authenticated users to delete employee documents" ON storage.objects
FOR DELETE USING (
  bucket_id = 'employee-documents' AND
  auth.role() = 'authenticated'
);

-- =====================================================
-- 4. ROW LEVEL SECURITY FOR DOCUMENTS TABLE
-- =====================================================

-- Enable RLS on the documents table
ALTER TABLE public.hr_employee_documents ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users to view employee documents" ON public.hr_employee_documents;
DROP POLICY IF EXISTS "Allow authenticated users to insert employee documents" ON public.hr_employee_documents;
DROP POLICY IF EXISTS "Allow authenticated users to update employee documents" ON public.hr_employee_documents;
DROP POLICY IF EXISTS "Allow authenticated users to delete employee documents" ON public.hr_employee_documents;

-- Policy for authenticated users to read all documents
CREATE POLICY "Allow authenticated users to view employee documents" 
ON public.hr_employee_documents FOR SELECT 
USING (auth.role() = 'authenticated');

-- Policy for authenticated users to insert documents
CREATE POLICY "Allow authenticated users to insert employee documents" 
ON public.hr_employee_documents FOR INSERT 
WITH CHECK (auth.role() = 'authenticated');

-- Policy for authenticated users to update documents
CREATE POLICY "Allow authenticated users to update employee documents" 
ON public.hr_employee_documents FOR UPDATE 
USING (auth.role() = 'authenticated');

-- Policy for authenticated users to delete documents
CREATE POLICY "Allow authenticated users to delete employee documents" 
ON public.hr_employee_documents FOR DELETE 
USING (auth.role() = 'authenticated');

-- =====================================================
-- 5. STORAGE FOLDER STRUCTURE SETUP
-- =====================================================

-- The application will create folders automatically:
-- employee-documents/
-- ├── employees/
--     ├── 1/
--     │   ├── 1_health_card_1727389234567.jpg
--     │   ├── 1_passport_1727389445123.png
--     │   └── 1_resume_1727389556789.pdf
--     ├── 10/
--     │   ├── 10_resident_id_1727389667890.jpg
--     │   └── 10_other_1_1727389778901.pdf
--     └── ...

-- =====================================================
-- 6. DOCUMENT TYPES REFERENCE
-- =====================================================

-- Supported document types in the application:
-- 'health_card'    - Health Card (JPG, PNG, WebP, 5MB, Expiry Required)
-- 'resident_id'    - Resident ID (JPG, PNG, WebP, 5MB, Expiry Required) 
-- 'passport'       - Passport (JPG, PNG, WebP, 5MB, Expiry Required)
-- 'resume'         - Résumé (PDF, DOC, DOCX, 10MB, No Expiry)
-- 'other_1'        - Other Document 1 (All types, 10MB, Custom Name, Optional Expiry)
-- 'other_2'        - Other Document 2 (All types, 10MB, Custom Name, Optional Expiry)
-- 'other_3'        - Other Document 3 (All types, 10MB, Custom Name, Optional Expiry)
-- 'other_4'        - Other Document 4 (All types, 10MB, Custom Name, Optional Expiry)

-- =====================================================
-- 7. VERIFICATION QUERIES
-- =====================================================

-- Check if table exists and has correct structure
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    character_maximum_length,
    column_default
FROM information_schema.columns 
WHERE table_name = 'hr_employee_documents' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if storage bucket exists
SELECT * FROM storage.buckets WHERE id = 'employee-documents';

-- Check storage policies
SELECT 
    schemaname,
    tablename, 
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'objects' 
AND schemaname = 'storage'
AND policyname LIKE '%employee documents%';

-- Check table policies
SELECT 
    schemaname,
    tablename, 
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'hr_employee_documents' 
AND schemaname = 'public';

-- Success message
SELECT 'HR Employee Documents table and storage setup completed successfully!' as result;

-- =====================================================
-- SETUP INSTRUCTIONS:
-- =====================================================
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Verify the bucket was created in Storage > Buckets
-- 3. Check that policies are active in Authentication > Policies
-- 4. Test file upload through the application
-- 5. Check that files appear in Storage > employee-documents bucket
-- =====================================================