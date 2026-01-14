-- Add probation period expiry date to hr_employee_master table

ALTER TABLE hr_employee_master
ADD COLUMN IF NOT EXISTS probation_period_expiry_date DATE;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_probation_period_expiry_date ON hr_employee_master(probation_period_expiry_date);
