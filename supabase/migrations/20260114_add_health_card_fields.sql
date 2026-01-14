-- Add Health Card columns to hr_employee_master table
ALTER TABLE hr_employee_master
ADD COLUMN health_card_number VARCHAR(50),
ADD COLUMN health_card_expiry_date DATE,
ADD COLUMN health_card_document_url VARCHAR(500);

-- Create indexes for better query performance
CREATE INDEX idx_hr_employee_master_health_card_expiry_date ON hr_employee_master(health_card_expiry_date);
