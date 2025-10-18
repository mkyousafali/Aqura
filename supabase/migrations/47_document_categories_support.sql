-- Add document categories support to hr_employee_documents table
-- This migration adds structured support for categorized documents with specific fields

-- Create enum type for document categories first
DO $$ BEGIN
    CREATE TYPE document_category_enum AS ENUM (
        'warnings',
        'sick_leave', 
        'special_leave',
        'resignation',
        'contract_objection',
        'annual_leave',
        'other'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add document category column with proper enum type and default
ALTER TABLE hr_employee_documents 
ADD COLUMN IF NOT EXISTS document_category document_category_enum DEFAULT 'other';

-- Add category-specific fields
ALTER TABLE hr_employee_documents ADD COLUMN IF NOT EXISTS category_start_date DATE;
ALTER TABLE hr_employee_documents ADD COLUMN IF NOT EXISTS category_end_date DATE;
ALTER TABLE hr_employee_documents ADD COLUMN IF NOT EXISTS category_days INTEGER;
ALTER TABLE hr_employee_documents ADD COLUMN IF NOT EXISTS category_last_working_day DATE;
ALTER TABLE hr_employee_documents ADD COLUMN IF NOT EXISTS category_reason TEXT;
ALTER TABLE hr_employee_documents ADD COLUMN IF NOT EXISTS category_details TEXT;
ALTER TABLE hr_employee_documents ADD COLUMN IF NOT EXISTS category_content TEXT;

-- Add indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_category 
ON hr_employee_documents(document_category);

CREATE INDEX IF NOT EXISTS idx_hr_employee_documents_category_dates 
ON hr_employee_documents(document_category, category_start_date, category_end_date) 
WHERE category_start_date IS NOT NULL;

-- Add constraints for category-specific validations
ALTER TABLE hr_employee_documents ADD CONSTRAINT check_leave_dates 
CHECK (
    (document_category NOT IN ('sick_leave', 'special_leave', 'annual_leave')) 
    OR 
    (category_start_date IS NULL OR category_end_date IS NULL OR category_start_date <= category_end_date)
);

-- Add constraint for resignation last working day
ALTER TABLE hr_employee_documents ADD CONSTRAINT check_resignation_last_working_day 
CHECK (
    (document_category != 'resignation') 
    OR 
    (category_last_working_day IS NOT NULL)
);

-- Update existing other documents to have proper category
UPDATE hr_employee_documents 
SET document_category = 'other'
WHERE document_type LIKE 'other_%' AND document_category IS NULL;

-- Create a function to automatically calculate days between dates
CREATE OR REPLACE FUNCTION calculate_category_days()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-calculate days for leave categories
    IF NEW.document_category IN ('sick_leave', 'special_leave', 'annual_leave') 
       AND NEW.category_start_date IS NOT NULL 
       AND NEW.category_end_date IS NOT NULL THEN
        NEW.category_days := NEW.category_end_date - NEW.category_start_date + 1;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-calculate days
DROP TRIGGER IF EXISTS trigger_calculate_category_days ON hr_employee_documents;
CREATE TRIGGER trigger_calculate_category_days
    BEFORE INSERT OR UPDATE ON hr_employee_documents
    FOR EACH ROW
    EXECUTE FUNCTION calculate_category_days();

-- Create view for document categories with enhanced information
CREATE OR REPLACE VIEW hr_document_categories_summary AS
SELECT 
    d.employee_id,
    e.name as employee_name,
    e.employee_id as employee_code,
    d.document_category,
    COUNT(*) as document_count,
    MIN(d.upload_date) as first_document_date,
    MAX(d.upload_date) as latest_document_date,
    -- Leave-specific aggregations
    CASE 
        WHEN d.document_category IN ('sick_leave', 'special_leave', 'annual_leave') 
        THEN SUM(d.category_days) 
        ELSE NULL 
    END as total_leave_days,
    -- Warning count
    CASE 
        WHEN d.document_category = 'warnings' 
        THEN COUNT(*) 
        ELSE NULL 
    END as warning_count
FROM hr_employee_documents d
JOIN hr_employees e ON d.employee_id = e.id
WHERE d.is_active = true 
  AND d.document_category IS NOT NULL
GROUP BY d.employee_id, e.name, e.employee_id, d.document_category;

-- Create function to get category-specific document statistics
CREATE OR REPLACE FUNCTION get_employee_document_category_stats(emp_id UUID)
RETURNS TABLE(
    category document_category_enum,
    count BIGINT,
    total_days INTEGER,
    latest_date TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.document_category::document_category_enum,
        COUNT(*)::BIGINT,
        SUM(COALESCE(d.category_days, 0))::INTEGER,
        MAX(d.upload_date)
    FROM hr_employee_documents d
    WHERE d.employee_id = emp_id 
      AND d.is_active = true 
      AND d.document_category IS NOT NULL
    GROUP BY d.document_category;
END;
$$ LANGUAGE plpgsql;

-- Enable RLS for document categories (simplified policies)
ALTER TABLE hr_employee_documents ENABLE ROW LEVEL SECURITY;

-- Basic policy to allow authenticated users to access documents
-- More specific policies can be added later when role system is properly connected
CREATE POLICY "Authenticated users can access hr documents" ON hr_employee_documents
    FOR ALL USING (auth.uid() IS NOT NULL);

-- Add comments for documentation
COMMENT ON COLUMN hr_employee_documents.document_category IS 'Document category for structured classification';
COMMENT ON COLUMN hr_employee_documents.category_start_date IS 'Start date for leave-type documents';
COMMENT ON COLUMN hr_employee_documents.category_end_date IS 'End date for leave-type documents';
COMMENT ON COLUMN hr_employee_documents.category_days IS 'Auto-calculated days between start and end dates';
COMMENT ON COLUMN hr_employee_documents.category_last_working_day IS 'Last working day for resignation documents';
COMMENT ON COLUMN hr_employee_documents.category_reason IS 'Reason for resignation or contract objection';
COMMENT ON COLUMN hr_employee_documents.category_details IS 'Details for warnings or general information';
COMMENT ON COLUMN hr_employee_documents.category_content IS 'Content or additional information for leave requests';

-- Success message
DO $$ 
BEGIN 
    RAISE NOTICE 'Document categories support successfully added with structured fields and constraints';
END $$;