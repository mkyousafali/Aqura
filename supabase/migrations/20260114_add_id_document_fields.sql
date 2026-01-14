-- Add ID document columns to hr_employee_master table
ALTER TABLE hr_employee_master
ADD COLUMN id_number VARCHAR(50),
ADD COLUMN id_expiry_date DATE,
ADD COLUMN id_document_url VARCHAR(500);

-- Create indexes for better query performance
CREATE INDEX idx_hr_employee_master_id_expiry_date ON hr_employee_master(id_expiry_date);
