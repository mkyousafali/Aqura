-- Create hr_employee_documents table
CREATE TABLE IF NOT EXISTS public.hr_employee_documents (
  id UUID NOT NULL DEFAULT gen_random_uuid(),
  employee_id UUID NOT NULL,
  document_type VARCHAR(255) NOT NULL,
  document_name VARCHAR(255) NOT NULL,
  file_path TEXT NOT NULL,
  file_type VARCHAR(255),
  expiry_date DATE,
  upload_date DATE NOT NULL DEFAULT CURRENT_DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  document_number VARCHAR(255),
  document_description TEXT,
  health_card_number VARCHAR(255),
  health_card_expiry DATE,
  resident_id_number VARCHAR(255),
  resident_id_expiry DATE,
  passport_number VARCHAR(255),
  passport_expiry DATE,
  driving_license_number VARCHAR(255),
  driving_license_expiry DATE,
  resume_uploaded BOOLEAN DEFAULT false,
  document_category document_category_enum DEFAULT 'other',
  category_start_date DATE,
  category_end_date DATE,
  category_days INTEGER,
  category_last_working_day DATE,
  category_reason TEXT,
  category_details TEXT,
  category_content TEXT,
  PRIMARY KEY (id)
);

-- Indexes for hr_employee_documents
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_employee_id ON public.hr_employee_documents(employee_id);
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_created_at ON public.hr_employee_documents(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.hr_employee_documents ENABLE ROW LEVEL SECURITY;
