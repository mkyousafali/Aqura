-- Table 4: HR Employee Contacts
-- Purpose: Manages employee contact information including email, phone, and WhatsApp
-- Created: 2025-09-29

CREATE TABLE public.hr_employee_contacts (
  id uuid NOT NULL DEFAULT extensions.uuid_generate_v4(),
  employee_id uuid NOT NULL,
  email character varying(100) NULL,
  is_active boolean NULL DEFAULT true,
  created_at timestamp with time zone NULL DEFAULT now(),
  whatsapp_number character varying(20) NULL,
  contact_number character varying(20) NULL,
  CONSTRAINT hr_employee_contacts_pkey PRIMARY KEY (id),
  CONSTRAINT hr_employee_contacts_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES hr_employees (id)
) TABLESPACE pg_default;

-- Indexes for better performance
CREATE INDEX IF NOT EXISTS idx_hr_contacts_employee_id 
  ON public.hr_employee_contacts USING btree (employee_id) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_contacts_email 
  ON public.hr_employee_contacts USING btree (email) TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_contacts_active 
  ON public.hr_employee_contacts USING btree (is_active) TABLESPACE pg_default;

-- Comments for documentation
COMMENT ON TABLE public.hr_employee_contacts IS 'Employee contact information including email, phone numbers, and WhatsApp';
COMMENT ON COLUMN public.hr_employee_contacts.id IS 'Primary key - UUID generated automatically';
COMMENT ON COLUMN public.hr_employee_contacts.employee_id IS 'Foreign key reference to hr_employees table (required)';
COMMENT ON COLUMN public.hr_employee_contacts.email IS 'Employee email address (optional)';
COMMENT ON COLUMN public.hr_employee_contacts.is_active IS 'Whether the contact information is currently active/valid';
COMMENT ON COLUMN public.hr_employee_contacts.created_at IS 'Timestamp when the record was created';
COMMENT ON COLUMN public.hr_employee_contacts.whatsapp_number IS 'Employee WhatsApp number (optional)';
COMMENT ON COLUMN public.hr_employee_contacts.contact_number IS 'Employee primary contact/phone number (optional)';