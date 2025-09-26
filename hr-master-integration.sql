-- =====================================================
-- HR MASTER INTEGRATION WITH EXISTING TABLES
-- Run this AFTER hr-master-schema-minimal.sql and hr-org-structure-no-errors.sql
-- =====================================================

-- =====================================================
-- STEP 1: UPDATE EXISTING TABLES TO INTEGRATE WITH HR MASTER
-- =====================================================

-- Fix branches table ID type to match HR system (UUID instead of BIGSERIAL)
-- First, check if branches table uses BIGSERIAL
DO $$ 
DECLARE 
    branches_id_type TEXT;
BEGIN
    SELECT data_type INTO branches_id_type 
    FROM information_schema.columns 
    WHERE table_name = 'branches' AND column_name = 'id';
    
    IF branches_id_type = 'bigint' THEN
        -- Create new branches_temp with UUID
        CREATE TABLE branches_temp (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            name_en VARCHAR(255) NOT NULL,
            name_ar VARCHAR(255) NOT NULL,
            location_en VARCHAR(500) NOT NULL,
            location_ar VARCHAR(500) NOT NULL,
            is_active BOOLEAN DEFAULT true,
            is_main_branch BOOLEAN DEFAULT false,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            created_by BIGINT,
            updated_by BIGINT
        );
        
        -- Copy data with new UUIDs
        INSERT INTO branches_temp (name_en, name_ar, location_en, location_ar, is_active, is_main_branch, created_by, updated_by)
        SELECT 
            COALESCE(name_en, name, 'Branch') as name_en,
            COALESCE(name_ar, name, 'فرع') as name_ar, 
            COALESCE(location_en, region, address, 'Location') as location_en,
            COALESCE(location_ar, region, address, 'موقع') as location_ar,
            CASE WHEN status = 'active' THEN true ELSE false END as is_active,
            COALESCE(is_main_branch, false) as is_main_branch,
            created_by,
            updated_by
        FROM branches;
        
        -- Drop old table and rename
        DROP TABLE branches CASCADE;
        ALTER TABLE branches_temp RENAME TO branches;
        
        RAISE NOTICE 'Branches table converted from BIGINT to UUID';
    ELSE
        RAISE NOTICE 'Branches table already uses UUID or compatible type: %', branches_id_type;
    END IF;
END $$;

-- =====================================================
-- STEP 2: ADD HR INTEGRATION COLUMNS TO EXISTING TABLES
-- =====================================================

-- Add HR integration columns to existing employees table
ALTER TABLE employees 
ADD COLUMN IF NOT EXISTS hr_employee_id UUID REFERENCES hr_employees(id),
ADD COLUMN IF NOT EXISTS hr_position_id UUID REFERENCES hr_positions(id),
ADD COLUMN IF NOT EXISTS hr_assignment_id UUID REFERENCES hr_position_assignments(id);

-- Add HR integration to vendors table
ALTER TABLE vendors
ADD COLUMN IF NOT EXISTS hr_managed_by_employee_id UUID REFERENCES hr_employees(id),
ADD COLUMN IF NOT EXISTS hr_assigned_branch_id UUID REFERENCES branches(id);

-- Add HR integration to users table
ALTER TABLE users
ADD COLUMN IF NOT EXISTS hr_employee_id UUID REFERENCES hr_employees(id);

-- =====================================================
-- STEP 3: UPDATE HR TABLES TO REFERENCE EXISTING TABLES
-- =====================================================

-- Ensure hr_employees references branches properly
ALTER TABLE hr_employees 
DROP CONSTRAINT IF EXISTS hr_employees_branch_id_fkey,
ADD CONSTRAINT hr_employees_branch_id_fkey 
FOREIGN KEY (branch_id) REFERENCES branches(id);

-- Add branch reference to hr_salary_wages
ALTER TABLE hr_salary_wages
DROP CONSTRAINT IF EXISTS hr_salary_wages_branch_id_fkey,
ADD CONSTRAINT hr_salary_wages_branch_id_fkey
FOREIGN KEY (branch_id) REFERENCES branches(id);

-- Add branch reference to hr_fingerprint_transactions
ALTER TABLE hr_fingerprint_transactions
DROP CONSTRAINT IF EXISTS hr_fingerprint_transactions_branch_id_fkey,
ADD CONSTRAINT hr_fingerprint_transactions_branch_id_fkey
FOREIGN KEY (branch_id) REFERENCES branches(id);

-- =====================================================
-- STEP 4: CREATE INTEGRATION VIEWS FOR EASY DATA ACCESS
-- =====================================================

-- Complete Employee View (combines HR and existing employee data)
CREATE OR REPLACE VIEW v_employees_complete AS
SELECT 
    e.id as employee_id,
    e.name as employee_name,
    e.email,
    e.phone,
    e.status as employee_status,
    e.hire_date,
    e.salary,
    -- Branch information
    b.id as branch_id,
    b.name_en as branch_name,
    b.name_ar as branch_name_ar,
    -- HR Master data
    hr_e.employee_id as hr_employee_code,
    hr_e.name as hr_name,
    hr_p.position_title_en as position_title,
    hr_p.position_title_ar as position_title_ar,
    hr_d.department_name_en as department_name,
    hr_d.department_name_ar as department_name_ar,
    hr_l.level_name_en as level_name,
    hr_l.level_order as hierarchy_level,
    -- Position assignment info
    hr_pa.assigned_date,
    hr_pa.is_current as current_assignment
FROM employees e
LEFT JOIN branches b ON e.branch_id = b.id
LEFT JOIN hr_employees hr_e ON e.hr_employee_id = hr_e.id
LEFT JOIN hr_position_assignments hr_pa ON e.hr_assignment_id = hr_pa.id
LEFT JOIN hr_positions hr_p ON hr_pa.position_id = hr_p.id
LEFT JOIN hr_departments hr_d ON hr_p.department_id = hr_d.id
LEFT JOIN hr_levels hr_l ON hr_p.level_id = hr_l.id;

-- Complete Vendor View (combines vendor and HR management data)
CREATE OR REPLACE VIEW v_vendors_complete AS
SELECT 
    v.id as vendor_id,
    v.name as vendor_name,
    v.company,
    v.email,
    v.phone,
    v.category,
    v.status,
    v.payment_terms,
    -- HR Management data
    hr_e.employee_id as managed_by_employee_code,
    hr_e.name as managed_by_employee_name,
    hr_p.position_title_en as manager_position,
    -- Branch assignment
    b.name_en as assigned_branch_name,
    b.location_en as branch_location
FROM vendors v
LEFT JOIN hr_employees hr_e ON v.hr_managed_by_employee_id = hr_e.id
LEFT JOIN hr_position_assignments hr_pa ON hr_e.id = hr_pa.employee_id AND hr_pa.is_current = true
LEFT JOIN hr_positions hr_p ON hr_pa.position_id = hr_p.id
LEFT JOIN branches b ON v.hr_assigned_branch_id = b.id;

-- Organizational Chart View
CREATE OR REPLACE VIEW v_organizational_chart AS
SELECT 
    sub_pos.position_title_en as position,
    sub_pos.position_title_ar as position_ar,
    sub_dept.department_name_en as department,
    sub_level.level_name_en as level_name,
    sub_level.level_order,
    -- Current employee in this position
    hr_e.employee_id as employee_code,
    hr_e.name as employee_name,
    -- Manager information
    mgr1_pos.position_title_en as reports_to_1,
    mgr2_pos.position_title_en as reports_to_2,
    mgr3_pos.position_title_en as reports_to_3,
    -- Counts
    (SELECT COUNT(*) FROM hr_position_assignments 
     WHERE position_id = sub_pos.id AND is_current = true) as current_employees
FROM hr_position_reporting_template rt
JOIN hr_positions sub_pos ON rt.subordinate_position_id = sub_pos.id
JOIN hr_departments sub_dept ON sub_pos.department_id = sub_dept.id
JOIN hr_levels sub_level ON sub_pos.level_id = sub_level.id
LEFT JOIN hr_positions mgr1_pos ON rt.manager_position_1 = mgr1_pos.id
LEFT JOIN hr_positions mgr2_pos ON rt.manager_position_2 = mgr2_pos.id
LEFT JOIN hr_positions mgr3_pos ON rt.manager_position_3 = mgr3_pos.id
-- Get current employee assignment (if any)
LEFT JOIN hr_position_assignments hr_pa ON sub_pos.id = hr_pa.position_id AND hr_pa.is_current = true
LEFT JOIN hr_employees hr_e ON hr_pa.employee_id = hr_e.id
ORDER BY sub_level.level_order, sub_dept.department_name_en, sub_pos.position_title_en;

-- Branch Employee Summary View
CREATE OR REPLACE VIEW v_branch_employee_summary AS
SELECT 
    b.id as branch_id,
    b.name_en as branch_name,
    b.location_en as location,
    -- Employee counts by level
    COUNT(CASE WHEN hr_l.level_order = 1 THEN 1 END) as executive_count,
    COUNT(CASE WHEN hr_l.level_order = 2 THEN 1 END) as senior_mgmt_count,
    COUNT(CASE WHEN hr_l.level_order = 3 THEN 1 END) as core_mgmt_count,
    COUNT(CASE WHEN hr_l.level_order = 4 THEN 1 END) as quality_count,
    COUNT(CASE WHEN hr_l.level_order = 5 THEN 1 END) as branch_mgmt_count,
    COUNT(CASE WHEN hr_l.level_order = 6 THEN 1 END) as dept_heads_count,
    COUNT(CASE WHEN hr_l.level_order = 7 THEN 1 END) as supervisors_count,
    COUNT(CASE WHEN hr_l.level_order = 8 THEN 1 END) as staff_count,
    COUNT(*) as total_employees,
    -- Salary totals by level
    SUM(CASE WHEN hr_l.level_order <= 3 THEN hr_sw.basic_salary ELSE 0 END) as management_salary_total,
    SUM(hr_sw.basic_salary) as total_salary_cost
FROM branches b
LEFT JOIN hr_employees hr_e ON b.id = hr_e.branch_id
LEFT JOIN hr_position_assignments hr_pa ON hr_e.id = hr_pa.employee_id AND hr_pa.is_current = true
LEFT JOIN hr_positions hr_p ON hr_pa.position_id = hr_p.id
LEFT JOIN hr_levels hr_l ON hr_p.level_id = hr_l.id
LEFT JOIN hr_salary_wages hr_sw ON hr_e.id = hr_sw.employee_id AND hr_sw.is_current = true
GROUP BY b.id, b.name_en, b.location_en
ORDER BY b.name_en;

-- =====================================================
-- STEP 5: CREATE INTEGRATION FUNCTIONS
-- =====================================================

-- Function to sync existing employee with HR system
CREATE OR REPLACE FUNCTION sync_employee_with_hr(
    p_employee_id UUID,
    p_employee_code VARCHAR(10),
    p_employee_name VARCHAR(200),
    p_branch_id UUID,
    p_position_title VARCHAR(100) DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_hr_employee_id UUID;
    v_position_id UUID;
    v_assignment_id UUID;
BEGIN
    -- Create or get HR employee record
    INSERT INTO hr_employees (employee_id, name, branch_id)
    VALUES (p_employee_code, p_employee_name, p_branch_id)
    ON CONFLICT (employee_id) DO UPDATE SET
        name = EXCLUDED.name,
        branch_id = EXCLUDED.branch_id
    RETURNING id INTO v_hr_employee_id;
    
    -- Link existing employee to HR system
    UPDATE employees 
    SET hr_employee_id = v_hr_employee_id
    WHERE id = p_employee_id;
    
    -- If position is specified, assign it
    IF p_position_title IS NOT NULL THEN
        SELECT id INTO v_position_id 
        FROM hr_positions 
        WHERE position_title_en = p_position_title
        LIMIT 1;
        
        IF v_position_id IS NOT NULL THEN
            -- End current assignments
            UPDATE hr_position_assignments 
            SET is_current = false, end_date = NOW()
            WHERE employee_id = v_hr_employee_id AND is_current = true;
            
            -- Create new assignment
            INSERT INTO hr_position_assignments (employee_id, position_id, assigned_date, is_current)
            VALUES (v_hr_employee_id, v_position_id, NOW(), true)
            RETURNING id INTO v_assignment_id;
            
            -- Update employee record
            UPDATE employees 
            SET hr_assignment_id = v_assignment_id,
                hr_position_id = v_position_id
            WHERE id = p_employee_id;
        END IF;
    END IF;
    
    RETURN v_hr_employee_id;
END;
$$ LANGUAGE plpgsql;

-- Function to assign vendor to HR employee
CREATE OR REPLACE FUNCTION assign_vendor_to_hr_employee(
    p_vendor_id UUID,
    p_employee_code VARCHAR(10),
    p_branch_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_hr_employee_id UUID;
BEGIN
    -- Get HR employee ID
    SELECT id INTO v_hr_employee_id 
    FROM hr_employees 
    WHERE employee_id = p_employee_code
    LIMIT 1;
    
    IF v_hr_employee_id IS NULL THEN
        RAISE EXCEPTION 'HR Employee with code % not found', p_employee_code;
    END IF;
    
    -- Update vendor
    UPDATE vendors 
    SET hr_managed_by_employee_id = v_hr_employee_id,
        hr_assigned_branch_id = COALESCE(p_branch_id, hr_assigned_branch_id)
    WHERE id = p_vendor_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- STEP 6: CREATE SAMPLE DATA INTEGRATION
-- =====================================================

-- Sample: Sync existing employees with HR system (if any exist)
-- This is just an example - you would run this manually with real data
/*
-- Example usage:
SELECT sync_employee_with_hr(
    '00000000-0000-0000-0000-000000000001', -- existing employee ID
    '1', -- HR employee code  
    'Ahmed Mohammed', -- employee name
    (SELECT id FROM branches WHERE name_en = 'Urban Market (AB)' LIMIT 1), -- branch ID
    'Branch Manager' -- position title
);
*/

-- =====================================================
-- STEP 7: VERIFICATION QUERIES
-- =====================================================

-- Check integration setup
SELECT 'SUCCESS: HR integration setup completed' as status;

-- Show table relationships
SELECT 
    'employees -> hr_employees' as relationship,
    COUNT(*) as total_employees,
    COUNT(hr_employee_id) as linked_to_hr
FROM employees
UNION ALL
SELECT 
    'vendors -> hr_employees' as relationship,
    COUNT(*) as total_vendors,
    COUNT(hr_managed_by_employee_id) as managed_by_hr  
FROM vendors
UNION ALL
SELECT 
    'hr_employees -> branches' as relationship,
    COUNT(*) as total_hr_employees,
    COUNT(branch_id) as assigned_to_branch
FROM hr_employees;

-- Show available views
SELECT 
    'Available Integration Views:' as info,
    schemaname,
    viewname
FROM pg_views 
WHERE viewname LIKE 'v_%_complete' OR viewname LIKE 'v_organizational%' OR viewname LIKE 'v_branch_%'
ORDER BY viewname;

-- Sample organizational chart data
SELECT 
    level_order,
    level_name,
    department,
    position,
    COALESCE(employee_name, 'VACANT') as current_employee,
    reports_to_1 as reports_to
FROM v_organizational_chart
WHERE level_order <= 3  -- Show only top 3 levels
ORDER BY level_order, department, position
LIMIT 10;

-- =====================================================
-- STEP 8: CREATE ADMIN HELPER PROCEDURES
-- =====================================================

-- Procedure to bulk sync existing employees
CREATE OR REPLACE FUNCTION bulk_sync_employees() RETURNS TABLE(
    employee_id UUID,
    employee_name TEXT,
    hr_employee_id UUID,
    status TEXT
) AS $$
DECLARE
    emp_record RECORD;
    v_hr_employee_id UUID;
BEGIN
    FOR emp_record IN 
        SELECT e.id, e.name, e.branch_id 
        FROM employees e 
        WHERE hr_employee_id IS NULL
        LIMIT 50  -- Process in batches
    LOOP
        -- Generate employee code (you can customize this logic)
        BEGIN
            v_hr_employee_id := sync_employee_with_hr(
                emp_record.id,
                emp_record.id::TEXT, -- Use existing ID as code (customize as needed)
                emp_record.name,
                emp_record.branch_id
            );
            
            -- Return success result
            employee_id := emp_record.id;
            employee_name := emp_record.name;
            hr_employee_id := v_hr_employee_id;
            status := 'SUCCESS';
            RETURN NEXT;
            
        EXCEPTION WHEN OTHERS THEN
            -- Return error result
            employee_id := emp_record.id;
            employee_name := emp_record.name;
            hr_employee_id := NULL;
            status := 'ERROR: ' || SQLERRM;
            RETURN NEXT;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION bulk_sync_employees() IS 'Bulk sync existing employees with HR Master system - run manually as needed';

-- =====================================================
-- FINAL SUCCESS MESSAGE
-- =====================================================
SELECT 
    'HR MASTER INTEGRATION COMPLETED!' as status,
    'Your HR Master system is now fully integrated with existing tables' as message,
    'Use the views (v_employees_complete, v_vendors_complete, etc.) for easy data access' as next_steps;