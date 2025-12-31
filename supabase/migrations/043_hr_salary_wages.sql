-- HR Salary Wages Table Schema
CREATE TABLE IF NOT EXISTS hr_salary_wages (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  employee_id UUID NOT NULL,
  branch_id UUID NOT NULL,
  basic_salary NUMERIC NOT NULL,
  effective_from DATE NOT NULL,
  is_current BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
