-- Create hr_insurance_companies table
-- Stores insurance company information with auto-generated IDs (INC001, INC002, etc.)

CREATE TABLE IF NOT EXISTS hr_insurance_companies (
  id VARCHAR(15) PRIMARY KEY,
  name_en VARCHAR(255) NOT NULL,
  name_ar VARCHAR(255) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_hr_insurance_companies_name_en ON hr_insurance_companies(name_en);
CREATE INDEX IF NOT EXISTS idx_hr_insurance_companies_name_ar ON hr_insurance_companies(name_ar);

-- Create function to generate insurance company IDs (INC001, INC002, etc.)
CREATE OR REPLACE FUNCTION generate_insurance_company_id()
RETURNS TRIGGER AS $$
DECLARE
  max_id INTEGER;
  new_id VARCHAR(15);
BEGIN
  -- Extract the numeric part from the last ID and increment it
  SELECT COALESCE(MAX(CAST(SUBSTRING(id, 4) AS INTEGER)), 0) + 1
  INTO max_id
  FROM hr_insurance_companies
  WHERE id LIKE 'INC%';
  
  -- Format as INC001, INC002, etc.
  new_id := 'INC' || LPAD(max_id::TEXT, 3, '0');
  NEW.id := new_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-generate ID on insert
DROP TRIGGER IF EXISTS trg_generate_insurance_company_id ON hr_insurance_companies;
CREATE TRIGGER trg_generate_insurance_company_id
BEFORE INSERT ON hr_insurance_companies
FOR EACH ROW
EXECUTE FUNCTION generate_insurance_company_id();
