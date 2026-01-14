-- Add employment status toggle to hr_employee_master table

ALTER TABLE hr_employee_master
ADD COLUMN IF NOT EXISTS is_currently_employed BOOLEAN DEFAULT true;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_is_currently_employed ON hr_employee_master(is_currently_employed);
