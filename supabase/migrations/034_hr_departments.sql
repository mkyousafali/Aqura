-- HR Departments Table Schema
CREATE TABLE IF NOT EXISTS hr_departments (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  department_name_en VARCHAR NOT NULL,
  department_name_ar VARCHAR NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
