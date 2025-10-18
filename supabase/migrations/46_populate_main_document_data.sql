-- Populate existing main document data into dedicated columns
-- This migration updates existing records to populate the new dedicated columns

-- Update existing health card records
UPDATE hr_employee_documents 
SET 
    health_card_number = document_number,
    health_card_expiry = expiry_date
WHERE document_type = 'health_card' AND is_active = true;

-- Update existing resident ID records
UPDATE hr_employee_documents 
SET 
    resident_id_number = document_number,
    resident_id_expiry = expiry_date
WHERE document_type = 'resident_id' AND is_active = true;

-- Update existing passport records
UPDATE hr_employee_documents 
SET 
    passport_number = document_number,
    passport_expiry = expiry_date
WHERE document_type = 'passport' AND is_active = true;

-- Update existing driving license records
UPDATE hr_employee_documents 
SET 
    driving_license_number = document_number,
    driving_license_expiry = expiry_date
WHERE document_type = 'driving_license' AND is_active = true;

-- Update existing resume records
UPDATE hr_employee_documents 
SET resume_uploaded = true
WHERE document_type = 'resume' AND is_active = true;

-- Add success notice with counts
DO $$ 
DECLARE
    health_card_count INTEGER;
    resident_id_count INTEGER;
    passport_count INTEGER;
    driving_license_count INTEGER;
    resume_count INTEGER;
BEGIN 
    SELECT COUNT(*) INTO health_card_count FROM hr_employee_documents WHERE document_type = 'health_card' AND is_active = true;
    SELECT COUNT(*) INTO resident_id_count FROM hr_employee_documents WHERE document_type = 'resident_id' AND is_active = true;
    SELECT COUNT(*) INTO passport_count FROM hr_employee_documents WHERE document_type = 'passport' AND is_active = true;
    SELECT COUNT(*) INTO driving_license_count FROM hr_employee_documents WHERE document_type = 'driving_license' AND is_active = true;
    SELECT COUNT(*) INTO resume_count FROM hr_employee_documents WHERE document_type = 'resume' AND is_active = true;
    
    RAISE NOTICE 'Populated main document columns: Health Cards: %, Resident IDs: %, Passports: %, Driving Licenses: %, Resumes: %', 
        health_card_count, resident_id_count, passport_count, driving_license_count, resume_count;
END $$;