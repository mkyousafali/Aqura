-- Create hr_employees table for managing HR employee records
-- This table stores core employee information with branch relationships

-- Create the hr_employees table
CREATE TABLE IF NOT EXISTS public.hr_employees (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    employee_id CHARACTER VARYING(10) NOT NULL,
    branch_id BIGINT NOT NULL,
    hire_date DATE NULL,
    status CHARACTER VARYING(20) NULL DEFAULT 'active'::character varying,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    name CHARACTER VARYING(200) NOT NULL,
    
    CONSTRAINT hr_employees_pkey PRIMARY KEY (id),
    CONSTRAINT hr_employees_employee_id_branch_id_unique UNIQUE (employee_id, branch_id),
    CONSTRAINT hr_employees_branch_id_fkey 
        FOREIGN KEY (branch_id) REFERENCES branches (id)
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_hr_employees_employee_id_branch_id 
ON public.hr_employees USING btree (employee_id, branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_employees_employee_id 
ON public.hr_employees USING btree (employee_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_employees_branch_id 
ON public.hr_employees USING btree (branch_id) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_hr_employees_status 
ON public.hr_employees (status);

CREATE INDEX IF NOT EXISTS idx_hr_employees_hire_date 
ON public.hr_employees (hire_date) 
WHERE hire_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_employees_name 
ON public.hr_employees (name);

CREATE INDEX IF NOT EXISTS idx_hr_employees_active 
ON public.hr_employees (branch_id, status) 
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_hr_employees_created_at 
ON public.hr_employees (created_at DESC);

-- Create text search index for employee names
CREATE INDEX IF NOT EXISTS idx_hr_employees_name_search 
ON public.hr_employees USING gin (to_tsvector('english', name));

-- Add updated_at column and trigger
ALTER TABLE public.hr_employees 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_hr_employees_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_employees_updated_at 
BEFORE UPDATE ON hr_employees 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_employees_updated_at();

-- Add data validation constraints
ALTER TABLE public.hr_employees 
ADD CONSTRAINT chk_employee_id_format 
CHECK (employee_id ~ '^[A-Z0-9]{1,10}$');

ALTER TABLE public.hr_employees 
ADD CONSTRAINT chk_name_not_empty 
CHECK (TRIM(name) != '');

ALTER TABLE public.hr_employees 
ADD CONSTRAINT chk_status_valid 
CHECK (status IN ('active', 'inactive', 'terminated', 'suspended', 'on_leave'));

ALTER TABLE public.hr_employees 
ADD CONSTRAINT chk_hire_date_reasonable 
CHECK (hire_date IS NULL OR hire_date >= '1900-01-01' AND hire_date <= CURRENT_DATE + INTERVAL '1 year');

-- Add table and column comments
COMMENT ON TABLE public.hr_employees IS 'Core HR employee records with branch assignments';
COMMENT ON COLUMN public.hr_employees.id IS 'Unique identifier for the employee record';
COMMENT ON COLUMN public.hr_employees.employee_id IS 'Employee identification number (alphanumeric, max 10 chars)';
COMMENT ON COLUMN public.hr_employees.branch_id IS 'Reference to the branch where employee works';
COMMENT ON COLUMN public.hr_employees.name IS 'Full name of the employee';
COMMENT ON COLUMN public.hr_employees.hire_date IS 'Date when employee was hired';
COMMENT ON COLUMN public.hr_employees.status IS 'Current employment status';
COMMENT ON COLUMN public.hr_employees.created_at IS 'Timestamp when the record was created';
COMMENT ON COLUMN public.hr_employees.updated_at IS 'Timestamp when the record was last updated';

-- Create view for active employees
CREATE OR REPLACE VIEW active_employees AS
SELECT 
    e.id,
    e.employee_id,
    e.name,
    e.branch_id,
    b.branch_name_en,
    b.branch_name_ar,
    e.hire_date,
    e.created_at,
    e.updated_at
FROM hr_employees e
JOIN branches b ON e.branch_id = b.id
WHERE e.status = 'active'
ORDER BY e.name;

-- Create function to get employee by ID and branch
CREATE OR REPLACE FUNCTION get_employee_by_id(emp_id VARCHAR, br_id BIGINT DEFAULT NULL)
RETURNS TABLE(
    id UUID,
    employee_id VARCHAR,
    name VARCHAR,
    branch_id BIGINT,
    branch_name VARCHAR,
    hire_date DATE,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        e.id,
        e.employee_id,
        e.name,
        e.branch_id,
        b.branch_name_en as branch_name,
        e.hire_date,
        e.status
    FROM hr_employees e
    JOIN branches b ON e.branch_id = b.id
    WHERE e.employee_id = emp_id
      AND (br_id IS NULL OR e.branch_id = br_id)
    ORDER BY e.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Create function to generate next employee ID for a branch
CREATE OR REPLACE FUNCTION generate_next_employee_id(br_id BIGINT)
RETURNS VARCHAR AS $$
DECLARE
    branch_code VARCHAR(2);
    next_number INTEGER;
    next_id VARCHAR(10);
BEGIN
    -- Get branch code (first 2 letters of branch name or use ID)
    SELECT COALESCE(
        UPPER(LEFT(branch_name_en, 2)), 
        LPAD(br_id::TEXT, 2, '0')
    ) INTO branch_code
    FROM branches WHERE id = br_id;
    
    -- Get next number for this branch
    SELECT COALESCE(
        MAX(CAST(RIGHT(employee_id, LENGTH(employee_id) - 2) AS INTEGER)) + 1, 
        1
    ) INTO next_number
    FROM hr_employees 
    WHERE branch_id = br_id 
      AND employee_id ~ ('^' || branch_code || '[0-9]+$');
    
    -- Format the new employee ID
    next_id := branch_code || LPAD(next_number::TEXT, 6, '0');
    
    RETURN next_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to get employee statistics by branch
CREATE OR REPLACE FUNCTION get_branch_employee_stats(br_id BIGINT DEFAULT NULL)
RETURNS TABLE(
    branch_id BIGINT,
    branch_name VARCHAR,
    total_employees BIGINT,
    active_employees BIGINT,
    inactive_employees BIGINT,
    terminated_employees BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id as branch_id,
        b.branch_name_en as branch_name,
        COUNT(e.id) as total_employees,
        COUNT(e.id) FILTER (WHERE e.status = 'active') as active_employees,
        COUNT(e.id) FILTER (WHERE e.status = 'inactive') as inactive_employees,
        COUNT(e.id) FILTER (WHERE e.status = 'terminated') as terminated_employees
    FROM branches b
    LEFT JOIN hr_employees e ON b.id = e.branch_id
    WHERE br_id IS NULL OR b.id = br_id
    GROUP BY b.id, b.branch_name_en
    ORDER BY b.branch_name_en;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'hr_employees table created with branch relationships and utility functions';