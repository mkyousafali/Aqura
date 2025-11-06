-- ================================================================
-- TABLE SCHEMA: hr_employee_documents
-- Generated: 2025-11-06T11:09:39.011Z
-- Description: Complete schema definition with triggers and related functions
-- ================================================================

-- ================================================================
-- TABLE DEFINITION
-- ================================================================

CREATE TABLE IF NOT EXISTS public.hr_employee_documents (
    id uuid NOT NULL DEFAULT uuid_generate_v4(),
    employee_id uuid NOT NULL,
    document_type character varying NOT NULL,
    document_name character varying NOT NULL,
    file_path text NOT NULL,
    file_type character varying,
    expiry_date date,
    upload_date date NOT NULL DEFAULT CURRENT_DATE,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    document_number character varying,
    document_description text,
    health_card_number character varying,
    health_card_expiry date,
    resident_id_number character varying,
    resident_id_expiry date,
    passport_number character varying,
    passport_expiry date,
    driving_license_number character varying,
    driving_license_expiry date,
    resume_uploaded boolean DEFAULT false,
    document_category USER-DEFINED DEFAULT 'other'::document_category_enum,
    category_start_date date,
    category_end_date date,
    category_days integer,
    category_last_working_day date,
    category_reason text,
    category_details text,
    category_content text
);

-- Table comment
COMMENT ON TABLE public.hr_employee_documents IS 'Table for hr employee documents management';

-- Column comments
COMMENT ON COLUMN public.hr_employee_documents.id IS 'Primary key identifier';
COMMENT ON COLUMN public.hr_employee_documents.employee_id IS 'Foreign key reference to employee table';
COMMENT ON COLUMN public.hr_employee_documents.document_type IS 'document type field';
COMMENT ON COLUMN public.hr_employee_documents.document_name IS 'Name field';
COMMENT ON COLUMN public.hr_employee_documents.file_path IS 'file path field';
COMMENT ON COLUMN public.hr_employee_documents.file_type IS 'file type field';
COMMENT ON COLUMN public.hr_employee_documents.expiry_date IS 'Date field';
COMMENT ON COLUMN public.hr_employee_documents.upload_date IS 'Date field';
COMMENT ON COLUMN public.hr_employee_documents.is_active IS 'Boolean flag';
COMMENT ON COLUMN public.hr_employee_documents.created_at IS 'Timestamp when record was created';
COMMENT ON COLUMN public.hr_employee_documents.updated_at IS 'Timestamp when record was last updated';
COMMENT ON COLUMN public.hr_employee_documents.document_number IS 'Reference number';
COMMENT ON COLUMN public.hr_employee_documents.document_description IS 'document description field';
COMMENT ON COLUMN public.hr_employee_documents.health_card_number IS 'Reference number';
COMMENT ON COLUMN public.hr_employee_documents.health_card_expiry IS 'health card expiry field';
COMMENT ON COLUMN public.hr_employee_documents.resident_id_number IS 'Reference number';
COMMENT ON COLUMN public.hr_employee_documents.resident_id_expiry IS 'resident id expiry field';
COMMENT ON COLUMN public.hr_employee_documents.passport_number IS 'Reference number';
COMMENT ON COLUMN public.hr_employee_documents.passport_expiry IS 'passport expiry field';
COMMENT ON COLUMN public.hr_employee_documents.driving_license_number IS 'Reference number';
COMMENT ON COLUMN public.hr_employee_documents.driving_license_expiry IS 'driving license expiry field';
COMMENT ON COLUMN public.hr_employee_documents.resume_uploaded IS 'Boolean flag';
COMMENT ON COLUMN public.hr_employee_documents.document_category IS 'document category field';
COMMENT ON COLUMN public.hr_employee_documents.category_start_date IS 'Date field';
COMMENT ON COLUMN public.hr_employee_documents.category_end_date IS 'Date field';
COMMENT ON COLUMN public.hr_employee_documents.category_days IS 'category days field';
COMMENT ON COLUMN public.hr_employee_documents.category_last_working_day IS 'category last working day field';
COMMENT ON COLUMN public.hr_employee_documents.category_reason IS 'category reason field';
COMMENT ON COLUMN public.hr_employee_documents.category_details IS 'category details field';
COMMENT ON COLUMN public.hr_employee_documents.category_content IS 'category content field';

-- ================================================================
-- INDEXES
-- ================================================================

-- Primary key index
CREATE UNIQUE INDEX IF NOT EXISTS hr_employee_documents_pkey ON public.hr_employee_documents USING btree (id);

-- Foreign key index for employee_id
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_employee_id ON public.hr_employee_documents USING btree (employee_id);

-- Date index for expiry_date
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_expiry_date ON public.hr_employee_documents USING btree (expiry_date);

-- Date index for upload_date
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_upload_date ON public.hr_employee_documents USING btree (upload_date);

-- Date index for health_card_expiry
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_health_card_expiry ON public.hr_employee_documents USING btree (health_card_expiry);

-- Date index for resident_id_expiry
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_resident_id_expiry ON public.hr_employee_documents USING btree (resident_id_expiry);

-- Date index for passport_expiry
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_passport_expiry ON public.hr_employee_documents USING btree (passport_expiry);

-- Date index for driving_license_expiry
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_driving_license_expiry ON public.hr_employee_documents USING btree (driving_license_expiry);

-- Date index for category_start_date
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_category_start_date ON public.hr_employee_documents USING btree (category_start_date);

-- Date index for category_end_date
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_category_end_date ON public.hr_employee_documents USING btree (category_end_date);

-- Date index for category_last_working_day
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_category_last_working_day ON public.hr_employee_documents USING btree (category_last_working_day);

-- ================================================================
-- TRIGGERS
-- ================================================================

-- No triggers defined for hr_employee_documents

-- ================================================================
-- ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS
ALTER TABLE public.hr_employee_documents ENABLE ROW LEVEL SECURITY;

-- Basic RLS policies (customize as needed)
CREATE POLICY "hr_employee_documents_select_policy" ON public.hr_employee_documents
    FOR SELECT USING (true);

CREATE POLICY "hr_employee_documents_insert_policy" ON public.hr_employee_documents
    FOR INSERT WITH CHECK (true);

CREATE POLICY "hr_employee_documents_update_policy" ON public.hr_employee_documents
    FOR UPDATE USING (true);

CREATE POLICY "hr_employee_documents_delete_policy" ON public.hr_employee_documents
    FOR DELETE USING (true);

-- ================================================================
-- RELATED FUNCTIONS
-- ================================================================

-- No specific related functions found for hr_employee_documents

-- ================================================================
-- USAGE EXAMPLES
-- ================================================================

-- Insert example
/*
INSERT INTO public.hr_employee_documents (employee_id, document_type, document_name)
VALUES ('uuid-example', 'example', 'example');
*/

-- Select example
/*
SELECT * FROM public.hr_employee_documents 
WHERE employee_id = $1;
*/

-- Update example
/*
UPDATE public.hr_employee_documents 
SET updated_at = NOW()
WHERE id = $1;
*/

-- ================================================================
-- END OF HR_EMPLOYEE_DOCUMENTS SCHEMA
-- ================================================================
