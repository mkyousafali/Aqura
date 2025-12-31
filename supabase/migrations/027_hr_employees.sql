-- HR Employees Table Schema
CREATE TABLE IF NOT EXISTS hr_employees (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  employee_id VARCHAR NOT NULL,
  bigint branch_id BIGINT NOT NULL,
  hire_date DATE,
  status VARCHAR DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  name VARCHAR NOT NULL,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
