-- Add Driving Licence columns to hr_employee_master table
ALTER TABLE hr_employee_master
ADD COLUMN driving_licence_number VARCHAR(50),
ADD COLUMN driving_licence_expiry_date DATE,
ADD COLUMN driving_licence_document_url VARCHAR(500);

-- Create indexes for better query performance
CREATE INDEX idx_hr_employee_master_driving_licence_expiry_date ON hr_employee_master(driving_licence_expiry_date);
