-- Add health educational renewal date to hr_employee_master table

ALTER TABLE hr_employee_master
ADD COLUMN IF NOT EXISTS health_educational_renewal_date DATE;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_health_educational_renewal_date ON hr_employee_master(health_educational_renewal_date);
