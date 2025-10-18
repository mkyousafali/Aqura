-- Add separate columns for main document types in hr_employee_documents table
-- This creates dedicated columns for each of the 5 main document types for easier querying

-- Add specific document type columns
ALTER TABLE public.hr_employee_documents 
ADD COLUMN IF NOT EXISTS health_card_number CHARACTER VARYING(100) NULL,
ADD COLUMN IF NOT EXISTS health_card_expiry DATE NULL,
ADD COLUMN IF NOT EXISTS resident_id_number CHARACTER VARYING(100) NULL,
ADD COLUMN IF NOT EXISTS resident_id_expiry DATE NULL,
ADD COLUMN IF NOT EXISTS passport_number CHARACTER VARYING(100) NULL,
ADD COLUMN IF NOT EXISTS passport_expiry DATE NULL,
ADD COLUMN IF NOT EXISTS driving_license_number CHARACTER VARYING(100) NULL,
ADD COLUMN IF NOT EXISTS driving_license_expiry DATE NULL,
ADD COLUMN IF NOT EXISTS resume_uploaded BOOLEAN DEFAULT FALSE;

-- Add indexes for the new columns
CREATE INDEX IF NOT EXISTS idx_hr_documents_health_card_number 
ON public.hr_employee_documents USING btree (health_card_number) 
WHERE health_card_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_documents_resident_id_number 
ON public.hr_employee_documents USING btree (resident_id_number) 
WHERE resident_id_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_documents_passport_number 
ON public.hr_employee_documents USING btree (passport_number) 
WHERE passport_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_documents_driving_license_number 
ON public.hr_employee_documents USING btree (driving_license_number) 
WHERE driving_license_number IS NOT NULL;

-- Add indexes for expiry dates
CREATE INDEX IF NOT EXISTS idx_hr_documents_health_card_expiry 
ON public.hr_employee_documents USING btree (health_card_expiry) 
WHERE health_card_expiry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_documents_resident_id_expiry 
ON public.hr_employee_documents USING btree (resident_id_expiry) 
WHERE resident_id_expiry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_documents_passport_expiry 
ON public.hr_employee_documents USING btree (passport_expiry) 
WHERE passport_expiry IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_documents_driving_license_expiry 
ON public.hr_employee_documents USING btree (driving_license_expiry) 
WHERE driving_license_expiry IS NOT NULL;

-- Add comments for the new columns
COMMENT ON COLUMN public.hr_employee_documents.health_card_number IS 'Health card document number/ID';
COMMENT ON COLUMN public.hr_employee_documents.health_card_expiry IS 'Health card expiry date';
COMMENT ON COLUMN public.hr_employee_documents.resident_id_number IS 'Resident ID document number';
COMMENT ON COLUMN public.hr_employee_documents.resident_id_expiry IS 'Resident ID expiry date';
COMMENT ON COLUMN public.hr_employee_documents.passport_number IS 'Passport document number';
COMMENT ON COLUMN public.hr_employee_documents.passport_expiry IS 'Passport expiry date';
COMMENT ON COLUMN public.hr_employee_documents.driving_license_number IS 'Driving license number';
COMMENT ON COLUMN public.hr_employee_documents.driving_license_expiry IS 'Driving license expiry date';
COMMENT ON COLUMN public.hr_employee_documents.resume_uploaded IS 'Flag indicating if resume has been uploaded';

-- Create a view for easy querying of all main documents per employee
CREATE OR REPLACE VIEW hr_employee_main_documents AS
SELECT 
    e.id as employee_id,
    e.employee_id as employee_code,
    e.name as employee_name,
    
    -- Health Card
    MAX(CASE WHEN d.document_type = 'health_card' THEN d.document_number END) as health_card_number,
    MAX(CASE WHEN d.document_type = 'health_card' THEN d.expiry_date END) as health_card_expiry,
    MAX(CASE WHEN d.document_type = 'health_card' THEN d.file_path END) as health_card_file,
    
    -- Resident ID
    MAX(CASE WHEN d.document_type = 'resident_id' THEN d.document_number END) as resident_id_number,
    MAX(CASE WHEN d.document_type = 'resident_id' THEN d.expiry_date END) as resident_id_expiry,
    MAX(CASE WHEN d.document_type = 'resident_id' THEN d.file_path END) as resident_id_file,
    
    -- Passport
    MAX(CASE WHEN d.document_type = 'passport' THEN d.document_number END) as passport_number,
    MAX(CASE WHEN d.document_type = 'passport' THEN d.expiry_date END) as passport_expiry,
    MAX(CASE WHEN d.document_type = 'passport' THEN d.file_path END) as passport_file,
    
    -- Driving License
    MAX(CASE WHEN d.document_type = 'driving_license' THEN d.document_number END) as driving_license_number,
    MAX(CASE WHEN d.document_type = 'driving_license' THEN d.expiry_date END) as driving_license_expiry,
    MAX(CASE WHEN d.document_type = 'driving_license' THEN d.file_path END) as driving_license_file,
    
    -- Resume
    MAX(CASE WHEN d.document_type = 'resume' THEN d.file_path END) as resume_file,
    CASE WHEN MAX(CASE WHEN d.document_type = 'resume' THEN 1 ELSE 0 END) = 1 THEN true ELSE false END as resume_uploaded,
    
    -- Document counts
    COUNT(CASE WHEN d.document_type IN ('health_card', 'resident_id', 'passport', 'driving_license', 'resume') THEN 1 END) as main_documents_count,
    COUNT(CASE WHEN d.document_type NOT IN ('health_card', 'resident_id', 'passport', 'driving_license', 'resume') THEN 1 END) as other_documents_count,
    
    -- Expiry status
    COUNT(CASE WHEN d.expiry_date IS NOT NULL AND d.expiry_date <= CURRENT_DATE + INTERVAL '30 days' AND d.expiry_date >= CURRENT_DATE THEN 1 END) as expiring_soon_count,
    COUNT(CASE WHEN d.expiry_date IS NOT NULL AND d.expiry_date < CURRENT_DATE THEN 1 END) as expired_count

FROM hr_employees e
LEFT JOIN hr_employee_documents d ON e.id = d.employee_id AND d.is_active = true
GROUP BY e.id, e.employee_id, e.name;

-- Add comment for the view
COMMENT ON VIEW hr_employee_main_documents IS 'Consolidated view of all main document types per employee for easy reporting';

-- Add success notice
DO $$ 
BEGIN 
    RAISE NOTICE 'Added separate columns for main document types and created consolidated view';
END $$;