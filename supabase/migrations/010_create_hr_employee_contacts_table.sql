-- Create hr_employee_contacts table
CREATE TABLE IF NOT EXISTS public.hr_employee_contacts (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL,
  email VARCHAR(255),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  whatsapp_number VARCHAR(255),
  contact_number VARCHAR(255),
  PRIMARY KEY (id)
);

-- Indexes for hr_employee_contacts
CREATE INDEX IF NOT EXISTS idx_hr_employee_contacts_employee_id ON public.hr_employee_contacts(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_employee_contacts_created_at ON public.hr_employee_contacts(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_employee_contacts ENABLE ROW LEVEL SECURITY;
