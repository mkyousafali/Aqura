-- Migration for table: hr_employee_main_documents
-- Generated on: 2025-10-30T21:55:45.324Z

CREATE TABLE IF NOT EXISTS public.hr_employee_main_documents (
    employee_id UUID NOT NULL,
    employee_code VARCHAR(50) NOT NULL,
    employee_name VARCHAR(255) NOT NULL,
    health_card_number JSONB,
    health_card_expiry JSONB,
    health_card_file JSONB,
    resident_id_number JSONB,
    resident_id_expiry JSONB,
    resident_id_file JSONB,
    passport_number JSONB,
    passport_expiry JSONB,
    passport_file JSONB,
    driving_license_number JSONB,
    driving_license_expiry JSONB,
    driving_license_file JSONB,
    resume_file JSONB,
    resume_uploaded BOOLEAN DEFAULT false NOT NULL,
    main_documents_count NUMERIC NOT NULL,
    other_documents_count NUMERIC NOT NULL,
    expiring_soon_count NUMERIC NOT NULL,
    expired_count NUMERIC NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hr_employee_main_documents_employee_id ON public.hr_employee_main_documents(employee_id);

-- Enable Row Level Security
ALTER TABLE public.hr_employee_main_documents ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.hr_employee_main_documents IS 'Generated from Aqura schema analysis';
