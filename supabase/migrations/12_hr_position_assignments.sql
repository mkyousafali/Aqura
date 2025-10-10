-- Create hr_position_assignments table for managing employee position assignments
-- This table tracks employee assignments to positions, departments, levels, and branches

-- Create the hr_position_assignments table
CREATE TABLE IF NOT EXISTS public.hr_position_assignments (
    id UUID NOT NULL DEFAULT extensions.uuid_generate_v4(),
    employee_id UUID NOT NULL,
    position_id UUID NOT NULL,
    department_id UUID NOT NULL,
    level_id UUID NOT NULL,
    branch_id BIGINT NOT NULL,
    effective_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_current BOOLEAN NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    CONSTRAINT hr_position_assignments_pkey PRIMARY KEY (id),
    CONSTRAINT hr_position_assignments_branch_id_fkey 
        FOREIGN KEY (branch_id) REFERENCES branches (id),
    CONSTRAINT hr_position_assignments_department_id_fkey 
        FOREIGN KEY (department_id) REFERENCES hr_departments (id),
    CONSTRAINT hr_position_assignments_employee_id_fkey 
        FOREIGN KEY (employee_id) REFERENCES hr_employees (id),
    CONSTRAINT hr_position_assignments_level_id_fkey 
        FOREIGN KEY (level_id) REFERENCES hr_levels (id),
    CONSTRAINT hr_position_assignments_position_id_fkey 
        FOREIGN KEY (position_id) REFERENCES hr_positions (id)
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_hr_assignments_employee_id 
ON public.hr_position_assignments USING btree (employee_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_branch_id 
ON public.hr_position_assignments USING btree (branch_id) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_hr_assignments_position_id 
ON public.hr_position_assignments (position_id);

CREATE INDEX IF NOT EXISTS idx_hr_assignments_department_id 
ON public.hr_position_assignments (department_id);

CREATE INDEX IF NOT EXISTS idx_hr_assignments_level_id 
ON public.hr_position_assignments (level_id);

CREATE INDEX IF NOT EXISTS idx_hr_assignments_current 
ON public.hr_position_assignments (is_current) 
WHERE is_current = true;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_effective_date 
ON public.hr_position_assignments (effective_date);

CREATE INDEX IF NOT EXISTS idx_hr_assignments_employee_current 
ON public.hr_position_assignments (employee_id, is_current) 
WHERE is_current = true;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_branch_current 
ON public.hr_position_assignments (branch_id, is_current) 
WHERE is_current = true;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_department_current 
ON public.hr_position_assignments (department_id, is_current) 
WHERE is_current = true;

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_hr_assignments_org_structure 
ON public.hr_position_assignments (department_id, level_id, position_id) 
WHERE is_current = true;

CREATE INDEX IF NOT EXISTS idx_hr_assignments_employee_history 
ON public.hr_position_assignments (employee_id, effective_date DESC);

-- Add end_date column for assignment periods
ALTER TABLE public.hr_position_assignments 
ADD COLUMN IF NOT EXISTS end_date DATE;

-- Add updated_at column and trigger
ALTER TABLE public.hr_position_assignments 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_hr_position_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_hr_position_assignments_updated_at 
BEFORE UPDATE ON hr_position_assignments 
FOR EACH ROW 
EXECUTE FUNCTION update_hr_position_assignments_updated_at();

-- Add data validation constraints
ALTER TABLE public.hr_position_assignments 
ADD CONSTRAINT chk_effective_date_reasonable 
CHECK (effective_date >= '1900-01-01' AND effective_date <= CURRENT_DATE + INTERVAL '1 year');

ALTER TABLE public.hr_position_assignments 
ADD CONSTRAINT chk_end_date_after_effective 
CHECK (end_date IS NULL OR end_date >= effective_date);

-- Ensure only one current assignment per employee
CREATE UNIQUE INDEX IF NOT EXISTS idx_hr_assignments_unique_current_employee 
ON public.hr_position_assignments (employee_id) 
WHERE is_current = true;

-- Add table and column comments
COMMENT ON TABLE public.hr_position_assignments IS 'Employee position assignments with organizational hierarchy';
COMMENT ON COLUMN public.hr_position_assignments.id IS 'Unique identifier for the assignment';
COMMENT ON COLUMN public.hr_position_assignments.employee_id IS 'Reference to the employee';
COMMENT ON COLUMN public.hr_position_assignments.position_id IS 'Reference to the assigned position';
COMMENT ON COLUMN public.hr_position_assignments.department_id IS 'Reference to the department';
COMMENT ON COLUMN public.hr_position_assignments.level_id IS 'Reference to the organizational level';
COMMENT ON COLUMN public.hr_position_assignments.branch_id IS 'Reference to the branch';
COMMENT ON COLUMN public.hr_position_assignments.effective_date IS 'Date when the assignment becomes effective';
COMMENT ON COLUMN public.hr_position_assignments.end_date IS 'Date when the assignment ends (NULL for current)';
COMMENT ON COLUMN public.hr_position_assignments.is_current IS 'Whether this is the current assignment';
COMMENT ON COLUMN public.hr_position_assignments.created_at IS 'Timestamp when the assignment was created';
COMMENT ON COLUMN public.hr_position_assignments.updated_at IS 'Timestamp when the assignment was last updated';

-- Create view for current assignments with details
CREATE OR REPLACE VIEW current_employee_assignments AS
SELECT 
    pa.id,
    pa.employee_id,
    e.employee_id as emp_code,
    e.name as employee_name,
    p.position_name_en,
    p.position_name_ar,
    d.department_name_en,
    d.department_name_ar,
    l.level_name_en,
    l.level_name_ar,
    l.level_order,
    b.branch_name_en,
    b.branch_name_ar,
    pa.effective_date,
    pa.created_at
FROM hr_position_assignments pa
JOIN hr_employees e ON pa.employee_id = e.id
JOIN hr_positions p ON pa.position_id = p.id
JOIN hr_departments d ON pa.department_id = d.id
JOIN hr_levels l ON pa.level_id = l.id
JOIN branches b ON pa.branch_id = b.id
WHERE pa.is_current = true
ORDER BY b.branch_name_en, d.department_name_en, l.level_order, e.name;

-- Create function to assign employee to position
CREATE OR REPLACE FUNCTION assign_employee_position(
    emp_id UUID,
    pos_id UUID,
    dept_id UUID,
    lvl_id UUID,
    br_id BIGINT,
    eff_date DATE DEFAULT CURRENT_DATE
)
RETURNS UUID AS $$
DECLARE
    assignment_id UUID;
BEGIN
    -- End current assignment if exists
    UPDATE hr_position_assignments 
    SET is_current = false, 
        end_date = eff_date - INTERVAL '1 day',
        updated_at = now()
    WHERE employee_id = emp_id AND is_current = true;
    
    -- Create new assignment
    INSERT INTO hr_position_assignments (
        employee_id, position_id, department_id, level_id, branch_id, effective_date
    ) VALUES (
        emp_id, pos_id, dept_id, lvl_id, br_id, eff_date
    ) RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to get employee assignment history
CREATE OR REPLACE FUNCTION get_employee_assignment_history(emp_id UUID)
RETURNS TABLE(
    assignment_id UUID,
    position_name VARCHAR,
    department_name VARCHAR,
    level_name VARCHAR,
    branch_name VARCHAR,
    effective_date DATE,
    end_date DATE,
    is_current BOOLEAN,
    duration INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pa.id,
        p.position_name_en,
        d.department_name_en,
        l.level_name_en,
        b.branch_name_en,
        pa.effective_date,
        pa.end_date,
        pa.is_current,
        CASE 
            WHEN pa.end_date IS NOT NULL 
            THEN pa.end_date - pa.effective_date
            ELSE CURRENT_DATE - pa.effective_date
        END as duration
    FROM hr_position_assignments pa
    JOIN hr_positions p ON pa.position_id = p.id
    JOIN hr_departments d ON pa.department_id = d.id
    JOIN hr_levels l ON pa.level_id = l.id
    JOIN branches b ON pa.branch_id = b.id
    WHERE pa.employee_id = emp_id
    ORDER BY pa.effective_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function to get organizational chart
CREATE OR REPLACE FUNCTION get_organizational_chart(br_id BIGINT DEFAULT NULL)
RETURNS TABLE(
    department_name VARCHAR,
    level_name VARCHAR,
    level_order INTEGER,
    position_name VARCHAR,
    employee_count BIGINT,
    employees TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.department_name_en,
        l.level_name_en,
        l.level_order,
        p.position_name_en,
        COUNT(pa.employee_id) as employee_count,
        STRING_AGG(e.name, ', ' ORDER BY e.name) as employees
    FROM hr_departments d
    CROSS JOIN hr_levels l
    CROSS JOIN hr_positions p
    LEFT JOIN hr_position_assignments pa ON (
        pa.department_id = d.id 
        AND pa.level_id = l.id 
        AND pa.position_id = p.id 
        AND pa.is_current = true
        AND (br_id IS NULL OR pa.branch_id = br_id)
    )
    LEFT JOIN hr_employees e ON pa.employee_id = e.id
    WHERE d.is_active = true 
      AND l.is_active = true 
      AND p.is_active = true
    GROUP BY d.department_name_en, l.level_name_en, l.level_order, p.position_name_en
    ORDER BY d.department_name_en, l.level_order, p.position_name_en;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'hr_position_assignments table created with organizational management features';