-- Create hr_salary_components table for managing salary allowances and deductions
-- This table stores additional salary components with flexible application periods

-- Create the hr_salary_components table
CREATE TABLE IF NOT EXISTS public.hr_salary_components (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    salary_id UUID NOT NULL,
    employee_id UUID NOT NULL,
    component_type CHARACTER VARYING(20) NOT NULL,
    component_name CHARACTER VARYING(100) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    is_enabled BOOLEAN NULL DEFAULT true,
    application_type CHARACTER VARYING(20) NULL,
    single_month CHARACTER VARYING(7) NULL,
    start_month CHARACTER VARYING(7) NULL,
    end_month CHARACTER VARYING(7) NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT hr_salary_components_pkey PRIMARY KEY (id),
    CONSTRAINT hr_salary_components_employee_id_fkey 
        FOREIGN KEY (employee_id) REFERENCES hr_employees (id),
    CONSTRAINT hr_salary_components_salary_id_fkey 
        FOREIGN KEY (salary_id) REFERENCES hr_salary_wages (id),
    CONSTRAINT chk_hr_components_type 
        CHECK (component_type::text = ANY (ARRAY[
            'ALLOWANCE'::character varying::text,
            'DEDUCTION'::character varying::text
        ])),
    CONSTRAINT chk_hr_components_app_type 
        CHECK (application_type::text = ANY (ARRAY[
            'single'::character varying::text,
            'multiple'::character varying::text
        ]))
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_hr_components_employee_id 
ON public.hr_salary_components USING btree (employee_id) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_hr_components_salary_id 
ON public.hr_salary_components (salary_id);

CREATE INDEX IF NOT EXISTS idx_hr_components_type 
ON public.hr_salary_components (component_type);

CREATE INDEX IF NOT EXISTS idx_hr_components_enabled 
ON public.hr_salary_components (is_enabled) 
WHERE is_enabled = true;

CREATE INDEX IF NOT EXISTS idx_hr_components_app_type 
ON public.hr_salary_components (application_type) 
WHERE application_type IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_components_single_month 
ON public.hr_salary_components (single_month) 
WHERE single_month IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_components_date_range 
ON public.hr_salary_components (start_month, end_month) 
WHERE start_month IS NOT NULL AND end_month IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_hr_components_employee_type 
ON public.hr_salary_components (employee_id, component_type, is_enabled);

CREATE INDEX IF NOT EXISTS idx_hr_components_salary_type 
ON public.hr_salary_components (salary_id, component_type, is_enabled);

-- Add updated_at column and trigger
ALTER TABLE public.hr_salary_components 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_hr_salary_components_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_salary_components_updated_at 
BEFORE UPDATE ON hr_salary_components 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_salary_components_updated_at();

-- Add data validation constraints
ALTER TABLE public.hr_salary_components 
ADD CONSTRAINT chk_component_name_not_empty 
CHECK (TRIM(component_name) != '');

ALTER TABLE public.hr_salary_components 
ADD CONSTRAINT chk_amount_not_zero 
CHECK (amount != 0);

ALTER TABLE public.hr_salary_components 
ADD CONSTRAINT chk_month_format_single 
CHECK (single_month IS NULL OR single_month ~ '^\d{4}-\d{2}$');

ALTER TABLE public.hr_salary_components 
ADD CONSTRAINT chk_month_format_start 
CHECK (start_month IS NULL OR start_month ~ '^\d{4}-\d{2}$');

ALTER TABLE public.hr_salary_components 
ADD CONSTRAINT chk_month_format_end 
CHECK (end_month IS NULL OR end_month ~ '^\d{4}-\d{2}$');

ALTER TABLE public.hr_salary_components 
ADD CONSTRAINT chk_date_range_valid 
CHECK (
    start_month IS NULL OR end_month IS NULL OR 
    start_month <= end_month
);

ALTER TABLE public.hr_salary_components 
ADD CONSTRAINT chk_application_consistency 
CHECK (
    (application_type = 'single' AND single_month IS NOT NULL AND start_month IS NULL AND end_month IS NULL) OR
    (application_type = 'multiple' AND single_month IS NULL AND start_month IS NOT NULL AND end_month IS NOT NULL) OR
    (application_type IS NULL)
);

-- Add table and column comments
COMMENT ON TABLE public.hr_salary_components IS 'Salary components including allowances and deductions with flexible application periods';
COMMENT ON COLUMN public.hr_salary_components.id IS 'Unique identifier for the salary component';
COMMENT ON COLUMN public.hr_salary_components.salary_id IS 'Reference to the base salary record';
COMMENT ON COLUMN public.hr_salary_components.employee_id IS 'Reference to the employee';
COMMENT ON COLUMN public.hr_salary_components.component_type IS 'Type of component (ALLOWANCE or DEDUCTION)';
COMMENT ON COLUMN public.hr_salary_components.component_name IS 'Name/description of the component';
COMMENT ON COLUMN public.hr_salary_components.amount IS 'Amount of the component (can be negative for deductions)';
COMMENT ON COLUMN public.hr_salary_components.is_enabled IS 'Whether this component is currently active';
COMMENT ON COLUMN public.hr_salary_components.application_type IS 'How the component is applied (single month or multiple months)';
COMMENT ON COLUMN public.hr_salary_components.single_month IS 'Specific month for single application (YYYY-MM format)';
COMMENT ON COLUMN public.hr_salary_components.start_month IS 'Start month for multiple application (YYYY-MM format)';
COMMENT ON COLUMN public.hr_salary_components.end_month IS 'End month for multiple application (YYYY-MM format)';
COMMENT ON COLUMN public.hr_salary_components.created_at IS 'Timestamp when the component was created';
COMMENT ON COLUMN public.hr_salary_components.updated_at IS 'Timestamp when the component was last updated';

-- Create view for active components
CREATE OR REPLACE VIEW active_salary_components AS
SELECT 
    sc.id,
    sc.salary_id,
    sc.employee_id,
    e.employee_id as emp_code,
    e.name as employee_name,
    sc.component_type,
    sc.component_name,
    sc.amount,
    sc.application_type,
    sc.single_month,
    sc.start_month,
    sc.end_month,
    sc.created_at,
    sc.updated_at
FROM hr_salary_components sc
JOIN hr_employees e ON sc.employee_id = e.id
WHERE sc.is_enabled = true
ORDER BY e.name, sc.component_type, sc.component_name;

-- Create function to get components for a specific month
CREATE OR REPLACE FUNCTION get_month_components(emp_id UUID, target_month VARCHAR)
RETURNS TABLE(
    component_id UUID,
    component_type VARCHAR,
    component_name VARCHAR,
    amount NUMERIC,
    application_type VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sc.id,
        sc.component_type,
        sc.component_name,
        sc.amount,
        sc.application_type
    FROM hr_salary_components sc
    WHERE sc.employee_id = emp_id
      AND sc.is_enabled = true
      AND (
          (sc.application_type = 'single' AND sc.single_month = target_month) OR
          (sc.application_type = 'multiple' AND target_month BETWEEN sc.start_month AND sc.end_month) OR
          (sc.application_type IS NULL)
      )
    ORDER BY sc.component_type, sc.component_name;
END;
$$ LANGUAGE plpgsql;

-- Create function to calculate total components by type for a month
CREATE OR REPLACE FUNCTION calculate_month_totals(emp_id UUID, target_month VARCHAR)
RETURNS TABLE(
    total_allowances NUMERIC,
    total_deductions NUMERIC,
    net_components NUMERIC,
    component_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(SUM(CASE WHEN sc.component_type = 'ALLOWANCE' THEN sc.amount ELSE 0 END), 0) as total_allowances,
        COALESCE(SUM(CASE WHEN sc.component_type = 'DEDUCTION' THEN ABS(sc.amount) ELSE 0 END), 0) as total_deductions,
        COALESCE(SUM(CASE 
            WHEN sc.component_type = 'ALLOWANCE' THEN sc.amount 
            WHEN sc.component_type = 'DEDUCTION' THEN -ABS(sc.amount)
            ELSE 0 
        END), 0) as net_components,
        COUNT(*)::INTEGER as component_count
    FROM hr_salary_components sc
    WHERE sc.employee_id = emp_id
      AND sc.is_enabled = true
      AND (
          (sc.application_type = 'single' AND sc.single_month = target_month) OR
          (sc.application_type = 'multiple' AND target_month BETWEEN sc.start_month AND sc.end_month) OR
          (sc.application_type IS NULL)
      );
END;
$$ LANGUAGE plpgsql;

-- Create function to get component summary by employee
CREATE OR REPLACE FUNCTION get_employee_component_summary(emp_id UUID)
RETURNS TABLE(
    component_type VARCHAR,
    component_count BIGINT,
    total_amount NUMERIC,
    avg_amount NUMERIC,
    active_components BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sc.component_type,
        COUNT(*) as component_count,
        SUM(sc.amount) as total_amount,
        AVG(sc.amount) as avg_amount,
        COUNT(*) FILTER (WHERE sc.is_enabled = true) as active_components
    FROM hr_salary_components sc
    WHERE sc.employee_id = emp_id
    GROUP BY sc.component_type
    ORDER BY sc.component_type;
END;
$$ LANGUAGE plpgsql;

-- Create function to validate component dates
CREATE OR REPLACE FUNCTION validate_component_dates()
RETURNS TABLE(
    component_id UUID,
    employee_name VARCHAR,
    component_name VARCHAR,
    issue_type VARCHAR,
    issue_description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sc.id,
        e.name,
        sc.component_name,
        'invalid_date_format'::VARCHAR,
        'Invalid month format detected'::TEXT
    FROM hr_salary_components sc
    JOIN hr_employees e ON sc.employee_id = e.id
    WHERE sc.is_enabled = true
      AND (
          (sc.single_month IS NOT NULL AND sc.single_month !~ '^\d{4}-\d{2}$') OR
          (sc.start_month IS NOT NULL AND sc.start_month !~ '^\d{4}-\d{2}$') OR
          (sc.end_month IS NOT NULL AND sc.end_month !~ '^\d{4}-\d{2}$')
      )
    
    UNION ALL
    
    SELECT 
        sc.id,
        e.name,
        sc.component_name,
        'inconsistent_application'::VARCHAR,
        'Application type and date fields do not match'::TEXT
    FROM hr_salary_components sc
    JOIN hr_employees e ON sc.employee_id = e.id
    WHERE sc.is_enabled = true
      AND NOT (
          (sc.application_type = 'single' AND sc.single_month IS NOT NULL AND sc.start_month IS NULL AND sc.end_month IS NULL) OR
          (sc.application_type = 'multiple' AND sc.single_month IS NULL AND sc.start_month IS NOT NULL AND sc.end_month IS NOT NULL) OR
          (sc.application_type IS NULL)
      );
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'hr_salary_components table created with flexible period management and calculation functions';