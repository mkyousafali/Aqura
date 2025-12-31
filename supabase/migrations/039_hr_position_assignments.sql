-- HR Position Assignments Table Schema
CREATE TABLE IF NOT EXISTS hr_position_assignments (
  id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  employee_id UUID NOT NULL,
  position_id UUID NOT NULL,
  department_id UUID NOT NULL,
  level_id UUID NOT NULL,
  branch_id BIGINT NOT NULL,
  effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
  is_current BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
