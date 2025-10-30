-- Migration for table: hr_employee_contacts
-- Generated on: 2025-10-30T21:55:45.312Z

CREATE TABLE IF NOT EXISTS public.hr_employee_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    employee_id UUID NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT true NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    whatsapp_number VARCHAR(255) NOT NULL,
    contact_number VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_hr_employee_contacts_employee_id ON public.hr_employee_contacts(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_employee_contacts_created_at ON public.hr_employee_contacts(created_at);

-- Enable Row Level Security
ALTER TABLE public.hr_employee_contacts ENABLE ROW LEVEL SECURITY;

-- Table comments
COMMENT ON TABLE public.hr_employee_contacts IS 'Generated from Aqura schema analysis';
