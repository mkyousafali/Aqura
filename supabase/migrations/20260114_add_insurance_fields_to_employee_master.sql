-- Add insurance fields to hr_employee_master table

-- Add insurance-related columns to hr_employee_master
ALTER TABLE hr_employee_master
ADD COLUMN IF NOT EXISTS insurance_expiry_date DATE,
ADD COLUMN IF NOT EXISTS insurance_company_id VARCHAR(15) REFERENCES hr_insurance_companies(id) ON DELETE SET NULL;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_insurance_expiry_date ON hr_employee_master(insurance_expiry_date);
CREATE INDEX IF NOT EXISTS idx_hr_employee_master_insurance_company_id ON hr_employee_master(insurance_company_id);
