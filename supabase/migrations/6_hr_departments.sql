-- Create hr_departments table for managing HR department records
-- This table stores department information with bilingual support

-- Create the hr_departments table
CREATE TABLE IF NOT EXISTS public.hr_departments (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    department_name_en CHARACTER VARYING(100) NOT NULL,
    department_name_ar CHARACTER VARYING(100) NOT NULL,
    is_active BOOLEAN NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT hr_departments_pkey PRIMARY KEY (id)
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_hr_departments_active 
ON public.hr_departments (is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_hr_departments_name_en 
ON public.hr_departments (department_name_en);

CREATE INDEX IF NOT EXISTS idx_hr_departments_name_ar 
ON public.hr_departments (department_name_ar);

CREATE INDEX IF NOT EXISTS idx_hr_departments_created_at 
ON public.hr_departments (created_at DESC);

-- Create text search indexes for both languages
CREATE INDEX IF NOT EXISTS idx_hr_departments_search_en 
ON public.hr_departments USING gin (to_tsvector('english', department_name_en));

CREATE INDEX IF NOT EXISTS idx_hr_departments_search_ar 
ON public.hr_departments USING gin (to_tsvector('arabic', department_name_ar));

-- Add unique constraints for department names
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_departments_unique_name_en 
ON public.hr_departments (LOWER(department_name_en)) 
WHERE is_active = true;

CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_departments_unique_name_ar 
ON public.hr_departments (LOWER(department_name_ar)) 
WHERE is_active = true;

-- Create trigger for updated_at timestamp
ALTER TABLE public.hr_departments 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_hr_departments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_departments_updated_at 
BEFORE UPDATE ON hr_departments 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_departments_updated_at();

-- Add table and column comments
COMMENT ON TABLE public.hr_departments IS 'HR department management with bilingual support';
COMMENT ON COLUMN public.hr_departments.id IS 'Unique identifier for the department';
COMMENT ON COLUMN public.hr_departments.department_name_en IS 'Department name in English';
COMMENT ON COLUMN public.hr_departments.department_name_ar IS 'Department name in Arabic';
COMMENT ON COLUMN public.hr_departments.is_active IS 'Whether the department is currently active';
COMMENT ON COLUMN public.hr_departments.created_at IS 'Timestamp when the department was created';
COMMENT ON COLUMN public.hr_departments.updated_at IS 'Timestamp when the department was last updated';

-- Add data validation constraints
ALTER TABLE public.hr_departments 
ADD CONSTRAINT chk_department_name_en_not_empty 
CHECK (TRIM(department_name_en) != '');

ALTER TABLE public.hr_departments 
ADD CONSTRAINT chk_department_name_ar_not_empty 
CHECK (TRIM(department_name_ar) != '');

-- Create view for active departments
CREATE OR REPLACE VIEW active_departments AS
SELECT 
    id,
    department_name_en,
    department_name_ar,
    created_at,
    updated_at
FROM hr_departments 
WHERE is_active = true
ORDER BY department_name_en;

-- Create function to get department by language
CREATE OR REPLACE FUNCTION get_department_name(dept_id UUID, lang_code VARCHAR DEFAULT 'en')
RETURNS VARCHAR AS $$
BEGIN
    RETURN CASE 
        WHEN lang_code = 'ar' THEN 
            (SELECT department_name_ar FROM hr_departments WHERE id = dept_id)
        ELSE 
            (SELECT department_name_en FROM hr_departments WHERE id = dept_id)
    END;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'hr_departments table created with bilingual support and constraints';