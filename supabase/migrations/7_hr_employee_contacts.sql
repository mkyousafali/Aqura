-- Create hr_employee_contacts table for managing employee contact information
-- This table stores various contact methods for employees

-- Create the hr_employee_contacts table
CREATE TABLE IF NOT EXISTS public.hr_employee_contacts (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    employee_id UUID NOT NULL,
    email CHARACTER VARYING(100) NULL,
    is_active BOOLEAN NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    whatsapp_number CHARACTER VARYING(20) NULL,
    contact_number CHARACTER VARYING(20) NULL,
    
    CONSTRAINT hr_employee_contacts_pkey PRIMARY KEY (id),
    CONSTRAINT hr_employee_contacts_employee_id_fkey 
        FOREIGN KEY (employee_id) REFERENCES hr_employees (id)
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_hr_contacts_employee_id 
ON public.hr_employee_contacts USING btree (employee_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_contacts_email 
ON public.hr_employee_contacts (email) 
WHERE email IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_contacts_whatsapp 
ON public.hr_employee_contacts (whatsapp_number) 
WHERE whatsapp_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_contacts_contact_number 
ON public.hr_employee_contacts (contact_number) 
WHERE contact_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_contacts_active 
ON public.hr_employee_contacts (is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_hr_contacts_employee_active 
ON public.hr_employee_contacts (employee_id, is_active);

-- Add updated_at column and trigger
ALTER TABLE public.hr_employee_contacts 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_hr_employee_contacts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_employee_contacts_updated_at 
BEFORE UPDATE ON hr_employee_contacts 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_employee_contacts_updated_at();

-- Add data validation constraints
ALTER TABLE public.hr_employee_contacts 
ADD CONSTRAINT chk_email_format 
CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

ALTER TABLE public.hr_employee_contacts 
ADD CONSTRAINT chk_whatsapp_format 
CHECK (whatsapp_number IS NULL OR whatsapp_number ~ '^\+?[0-9\s\-\(\)]+$');

ALTER TABLE public.hr_employee_contacts 
ADD CONSTRAINT chk_contact_format 
CHECK (contact_number IS NULL OR contact_number ~ '^\+?[0-9\s\-\(\)]+$');

ALTER TABLE public.hr_employee_contacts 
ADD CONSTRAINT chk_has_contact_method 
CHECK (email IS NOT NULL OR whatsapp_number IS NOT NULL OR contact_number IS NOT NULL);

-- Create unique constraints for active contacts
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_contacts_unique_email 
ON public.hr_employee_contacts (email) 
WHERE email IS NOT NULL AND is_active = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_contacts_unique_whatsapp 
ON public.hr_employee_contacts (whatsapp_number) 
WHERE whatsapp_number IS NOT NULL AND is_active = true;

-- Add table and column comments
COMMENT ON TABLE public.hr_employee_contacts IS 'Contact information for HR employees';
COMMENT ON COLUMN public.hr_employee_contacts.id IS 'Unique identifier for the contact record';
COMMENT ON COLUMN public.hr_employee_contacts.employee_id IS 'Reference to the employee';
COMMENT ON COLUMN public.hr_employee_contacts.email IS 'Employee email address';
COMMENT ON COLUMN public.hr_employee_contacts.whatsapp_number IS 'WhatsApp contact number';
COMMENT ON COLUMN public.hr_employee_contacts.contact_number IS 'Primary contact phone number';
COMMENT ON COLUMN public.hr_employee_contacts.is_active IS 'Whether the contact information is currently active';
COMMENT ON COLUMN public.hr_employee_contacts.created_at IS 'Timestamp when the contact was created';
COMMENT ON COLUMN public.hr_employee_contacts.updated_at IS 'Timestamp when the contact was last updated';

-- Create view for active contacts
CREATE OR REPLACE VIEW active_employee_contacts AS
SELECT 
    ec.id,
    ec.employee_id,
    ec.email,
    ec.whatsapp_number,
    ec.contact_number,
    ec.created_at,
    ec.updated_at
FROM hr_employee_contacts ec
WHERE ec.is_active = true;

-- Create function to get employee primary contact
CREATE OR REPLACE FUNCTION get_employee_primary_contact(emp_id UUID)
RETURNS TABLE(
    email VARCHAR,
    whatsapp_number VARCHAR,
    contact_number VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ec.email,
        ec.whatsapp_number,
        ec.contact_number
    FROM hr_employee_contacts ec
    WHERE ec.employee_id = emp_id 
      AND ec.is_active = true
    ORDER BY ec.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'hr_employee_contacts table created with validation and constraints';