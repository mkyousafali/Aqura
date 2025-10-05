-- HR Employee Contacts Schema
-- Manages employee contact information including email, phone, and WhatsApp

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

-- Index for better query performance
CREATE INDEX IF NOT EXISTS idx_hr_contacts_employee_id ON public.hr_employee_contacts USING btree (employee_id) TABLESPACE pg_default;