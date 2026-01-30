-- Add employment status effective date and reason columns to hr_employee_master table

ALTER TABLE hr_employee_master
ADD COLUMN IF NOT EXISTS employment_status_effective_date DATE,
ADD COLUMN IF NOT EXISTS employment_status_reason TEXT;

-- Create an index on the effective date column for performance
CREATE INDEX IF NOT EXISTS idx_employment_status_effective_date 
ON hr_employee_master(employment_status_effective_date);

-- Add comments to the columns
COMMENT ON COLUMN hr_employee_master.employment_status_effective_date 
IS 'Effective date for employment status changes (Resigned, Terminated, Run Away)';

COMMENT ON COLUMN hr_employee_master.employment_status_reason 
IS 'Reason for employment status change';
