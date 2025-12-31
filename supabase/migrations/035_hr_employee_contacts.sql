-- HR Employee Contacts Table Schema
CREATE TABLE IF NOT EXISTS hr_employee_contacts (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  employee_id UUID NOT NULL,
  email VARCHAR,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  whatsapp_number VARCHAR,
  contact_number VARCHAR
);
