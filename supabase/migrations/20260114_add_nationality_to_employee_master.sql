-- Add nationality column to hr_employee_master table
ALTER TABLE hr_employee_master
ADD COLUMN nationality_id VARCHAR(10) REFERENCES nationalities(id);

-- Create index on nationality_id for better query performance
CREATE INDEX idx_hr_employee_master_nationality_id ON hr_employee_master(nationality_id);
