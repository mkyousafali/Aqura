-- =====================================================
-- HR EMPLOYEE DOCUMENTS - SIMPLE SETUP (NO CONFLICTS)
-- Run this step by step if you encounter any errors
-- =====================================================

-- STEP 1: Create the table
CREATE TABLE IF NOT EXISTS public.hr_employee_documents (
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
  CONSTRAINT hr_employee_documents_employee_id_fkey FOREIGN KEY (employee_id) 
    REFERENCES hr_employees (id) ON DELETE CASCADE
);

-- STEP 2: Create indexes
CREATE INDEX IF NOT EXISTS idx_hr_documents_employee_id ON public.hr_employee_documents (employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_documents_type ON public.hr_employee_documents (document_type);
CREATE INDEX IF NOT EXISTS idx_hr_documents_expiry ON public.hr_employee_documents (expiry_date);

-- STEP 3: Create storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'employee-documents',
  'employee-documents', 
  true,
  10485760,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']
) ON CONFLICT (id) DO NOTHING;

-- STEP 4: Enable RLS
ALTER TABLE public.hr_employee_documents ENABLE ROW LEVEL SECURITY;

-- STEP 5: Create table policies (run these one by one if needed)
CREATE POLICY "hr_docs_select_policy" ON public.hr_employee_documents FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "hr_docs_insert_policy" ON public.hr_employee_documents FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "hr_docs_update_policy" ON public.hr_employee_documents FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "hr_docs_delete_policy" ON public.hr_employee_documents FOR DELETE USING (auth.role() = 'authenticated');

-- STEP 6: Create storage policies (run these one by one if needed)
CREATE POLICY "storage_upload_policy" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'employee-documents' AND auth.role() = 'authenticated');
CREATE POLICY "storage_select_policy" ON storage.objects FOR SELECT USING (bucket_id = 'employee-documents' AND auth.role() = 'authenticated');
CREATE POLICY "storage_update_policy" ON storage.objects FOR UPDATE USING (bucket_id = 'employee-documents' AND auth.role() = 'authenticated');
CREATE POLICY "storage_delete_policy" ON storage.objects FOR DELETE USING (bucket_id = 'employee-documents' AND auth.role() = 'authenticated');

-- Verification
SELECT 'Setup completed successfully!' as result;