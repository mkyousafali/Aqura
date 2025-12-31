-- HR Salary Components Table Schema
CREATE TABLE IF NOT EXISTS hr_salary_components (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  salary_id UUID NOT NULL,
  employee_id UUID NOT NULL,
  component_type VARCHAR NOT NULL,
  component_name VARCHAR NOT NULL,
  amount NUMERIC NOT NULL,
  is_enabled BOOLEAN DEFAULT true,
  application_type VARCHAR,
  single_month VARCHAR,
  start_month VARCHAR,
  end_month VARCHAR,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
