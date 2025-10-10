-- Create hr_salary_wages table for managing employee basic salary records
-- This table stores salary information with effective dates and current status

-- Create the hr_salary_wages table
CREATE TABLE IF NOT EXISTS public.hr_salary_wages (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    employee_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    basic_salary NUMERIC(12, 2) NOT NULL,
    effective_from DATE NOT NULL,
    is_current BOOLEAN NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT hr_salary_wages_pkey PRIMARY KEY (id),
    CONSTRAINT hr_salary_wages_employee_id_fkey 
        FOREIGN KEY (employee_id) REFERENCES hr_employees (id)
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_hr_salary_employee_id 
ON public.hr_salary_wages USING btree (employee_id) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_hr_salary_branch_id 
ON public.hr_salary_wages (branch_id);

CREATE INDEX IF NOT EXISTS idx_hr_salary_current 
ON public.hr_salary_wages (is_current) 
WHERE is_current = true;

CREATE INDEX IF NOT EXISTS idx_hr_salary_effective_from 
ON public.hr_salary_wages (effective_from);

CREATE INDEX IF NOT EXISTS idx_hr_salary_employee_current 
ON public.hr_salary_wages (employee_id, is_current) 
WHERE is_current = true;

CREATE INDEX IF NOT EXISTS idx_hr_salary_employee_effective 
ON public.hr_salary_wages (employee_id, effective_from DESC);

CREATE INDEX IF NOT EXISTS idx_hr_salary_branch_current 
ON public.hr_salary_wages (branch_id, is_current) 
WHERE is_current = true;

-- Add effective_to column for salary periods
ALTER TABLE public.hr_salary_wages 
ADD COLUMN IF NOT EXISTS effective_to DATE;

-- Add updated_at column and trigger
ALTER TABLE public.hr_salary_wages 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_hr_salary_wages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_salary_wages_updated_at 
BEFORE UPDATE ON hr_salary_wages 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_salary_wages_updated_at();

-- Add data validation constraints
ALTER TABLE public.hr_salary_wages 
ADD CONSTRAINT chk_basic_salary_positive 
CHECK (basic_salary > 0);

ALTER TABLE public.hr_salary_wages 
ADD CONSTRAINT chk_effective_from_reasonable 
CHECK (effective_from >= '1900-01-01' AND effective_from <= CURRENT_DATE + INTERVAL '1 year');

ALTER TABLE public.hr_salary_wages 
ADD CONSTRAINT chk_effective_to_after_from 
CHECK (effective_to IS NULL OR effective_to >= effective_from);

-- Ensure only one current salary per employee
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_salary_unique_current_employee 
ON public.hr_salary_wages (employee_id) 
WHERE is_current = true;

-- Add table and column comments
COMMENT ON TABLE public.hr_salary_wages IS 'Employee basic salary records with effective date tracking';
COMMENT ON COLUMN public.hr_salary_wages.id IS 'Unique identifier for the salary record';
COMMENT ON COLUMN public.hr_salary_wages.employee_id IS 'Reference to the employee';
COMMENT ON COLUMN public.hr_salary_wages.branch_id IS 'Branch associated with this salary record';
COMMENT ON COLUMN public.hr_salary_wages.basic_salary IS 'Basic salary amount';
COMMENT ON COLUMN public.hr_salary_wages.effective_from IS 'Date when this salary becomes effective';
COMMENT ON COLUMN public.hr_salary_wages.effective_to IS 'Date when this salary period ends (NULL for current)';
COMMENT ON COLUMN public.hr_salary_wages.is_current IS 'Whether this is the current active salary';
COMMENT ON COLUMN public.hr_salary_wages.created_at IS 'Timestamp when the salary record was created';
COMMENT ON COLUMN public.hr_salary_wages.updated_at IS 'Timestamp when the salary record was last updated';

-- Create view for current salaries with employee details
CREATE OR REPLACE VIEW current_employee_salaries AS
SELECT 
    sw.id,
    sw.employee_id,
    e.employee_id as emp_code,
    e.name as employee_name,
    e.branch_id as employee_branch_id,
    sw.branch_id as salary_branch_id,
    sw.basic_salary,
    sw.effective_from,
    sw.created_at,
    sw.updated_at
FROM hr_salary_wages sw
JOIN hr_employees e ON sw.employee_id = e.id
WHERE sw.is_current = true
ORDER BY e.name;

-- Create function to set new salary (automatically handles current salary updates)
CREATE OR REPLACE FUNCTION set_employee_salary(
    emp_id UUID,
    new_salary NUMERIC,
    effective_date DATE,
    salary_branch_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    salary_id UUID;
    emp_branch_id UUID;
BEGIN
    -- Get employee's branch if salary_branch_id is not provided
    IF salary_branch_id IS NULL THEN
        SELECT branch_id INTO emp_branch_id FROM hr_employees WHERE id = emp_id;
        salary_branch_id := emp_branch_id;
    END IF;
    
    -- End current salary
    UPDATE hr_salary_wages 
    SET is_current = false, 
        effective_to = effective_date - INTERVAL '1 day',
        updated_at = now()
    WHERE employee_id = emp_id AND is_current = true;
    
    -- Create new salary record
    INSERT INTO hr_salary_wages (
        employee_id, branch_id, basic_salary, effective_from
    ) VALUES (
        emp_id, salary_branch_id, new_salary, effective_date
    ) RETURNING id INTO salary_id;
    
    RETURN salary_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to get salary history for an employee
CREATE OR REPLACE FUNCTION get_employee_salary_history(emp_id UUID)
RETURNS TABLE(
    salary_id UUID,
    basic_salary NUMERIC,
    effective_from DATE,
    effective_to DATE,
    is_current BOOLEAN,
    duration INTERVAL,
    salary_change NUMERIC,
    change_percentage NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH salary_history AS (
        SELECT 
            sw.id,
            sw.basic_salary,
            sw.effective_from,
            sw.effective_to,
            sw.is_current,
            CASE 
                WHEN sw.effective_to IS NOT NULL 
                THEN sw.effective_to - sw.effective_from + INTERVAL '1 day'
                ELSE CURRENT_DATE - sw.effective_from + INTERVAL '1 day'
            END as duration,
            LAG(sw.basic_salary) OVER (ORDER BY sw.effective_from) as prev_salary
        FROM hr_salary_wages sw
        WHERE sw.employee_id = emp_id
    )
    SELECT 
        sh.id,
        sh.basic_salary,
        sh.effective_from,
        sh.effective_to,
        sh.is_current,
        sh.duration,
        CASE 
            WHEN sh.prev_salary IS NOT NULL 
            THEN sh.basic_salary - sh.prev_salary
            ELSE NULL
        END as salary_change,
        CASE 
            WHEN sh.prev_salary IS NOT NULL AND sh.prev_salary > 0
            THEN ((sh.basic_salary - sh.prev_salary) / sh.prev_salary * 100)
            ELSE NULL
        END as change_percentage
    FROM salary_history sh
    ORDER BY sh.effective_from DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to get salary for a specific date
CREATE OR REPLACE FUNCTION get_employee_salary_at_date(emp_id UUID, target_date DATE)
RETURNS TABLE(
    salary_id UUID,
    basic_salary NUMERIC,
    effective_from DATE,
    effective_to DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sw.id,
        sw.basic_salary,
        sw.effective_from,
        sw.effective_to
    FROM hr_salary_wages sw
    WHERE sw.employee_id = emp_id
      AND sw.effective_from <= target_date
      AND (sw.effective_to IS NULL OR sw.effective_to >= target_date)
    ORDER BY sw.effective_from DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Create function to get salary statistics by branch
CREATE OR REPLACE FUNCTION get_branch_salary_stats(br_id UUID DEFAULT NULL)
RETURNS TABLE(
    branch_id UUID,
    employee_count BIGINT,
    avg_salary NUMERIC,
    min_salary NUMERIC,
    max_salary NUMERIC,
    total_salary_budget NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sw.branch_id,
        COUNT(sw.employee_id) as employee_count,
        ROUND(AVG(sw.basic_salary), 2) as avg_salary,
        MIN(sw.basic_salary) as min_salary,
        MAX(sw.basic_salary) as max_salary,
        SUM(sw.basic_salary) as total_salary_budget
    FROM hr_salary_wages sw
    WHERE sw.is_current = true
      AND (br_id IS NULL OR sw.branch_id = br_id)
    GROUP BY sw.branch_id
    ORDER BY sw.branch_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to validate salary data
CREATE OR REPLACE FUNCTION validate_salary_data()
RETURNS TABLE(
    salary_id UUID,
    employee_name VARCHAR,
    issue_type VARCHAR,
    issue_description TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Multiple current salaries for same employee
    SELECT 
        sw.id,
        e.name,
        'multiple_current'::VARCHAR,
        'Employee has multiple current salary records'::TEXT
    FROM hr_salary_wages sw
    JOIN hr_employees e ON sw.employee_id = e.id
    WHERE sw.is_current = true
      AND sw.employee_id IN (
          SELECT employee_id 
          FROM hr_salary_wages 
          WHERE is_current = true 
          GROUP BY employee_id 
          HAVING COUNT(*) > 1
      )
    
    UNION ALL
    
    -- Gaps in salary history
    SELECT 
        sw.id,
        e.name,
        'salary_gap'::VARCHAR,
        'Gap detected in salary history'::TEXT
    FROM hr_salary_wages sw
    JOIN hr_employees e ON sw.employee_id = e.id
    WHERE sw.effective_to IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM hr_salary_wages sw2 
          WHERE sw2.employee_id = sw.employee_id 
            AND sw2.effective_from = sw.effective_to + INTERVAL '1 day'
      )
      AND sw.employee_id NOT IN (
          SELECT employee_id FROM hr_salary_wages WHERE is_current = true
      );
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'hr_salary_wages table created with salary management and tracking features';