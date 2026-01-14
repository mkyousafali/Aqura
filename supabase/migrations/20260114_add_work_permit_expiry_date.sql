-- Add work permit expiry date to hr_employee_master table

ALTER TABLE hr_employee_master
ADD COLUMN IF NOT EXISTS work_permit_expiry_date DATE;

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_work_permit_expiry_date ON hr_employee_master(work_permit_expiry_date);
