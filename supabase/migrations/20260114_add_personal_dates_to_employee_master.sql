-- Add personal date fields to hr_employee_master table

ALTER TABLE hr_employee_master
ADD COLUMN IF NOT EXISTS date_of_birth DATE,
ADD COLUMN IF NOT EXISTS join_date DATE;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_date_of_birth ON hr_employee_master(date_of_birth);
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_join_date ON hr_employee_master(join_date);
