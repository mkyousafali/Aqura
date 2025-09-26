-- =====================================================
-- HR MASTER INTEGRATION - FINAL EXECUTION SCRIPT
-- Copy this entire script and run it in Supabase SQL Editor
-- =====================================================

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- STEP 1: ADD HR INTEGRATION COLUMNS TO EXISTING TABLES
-- =====================================================
DO $$
BEGIN
    -- Add HR integration columns to existing employees table
    BEGIN
        ALTER TABLE employees 
        ADD COLUMN IF NOT EXISTS hr_employee_id UUID,
        ADD COLUMN IF NOT EXISTS hr_position_id UUID,
        ADD COLUMN IF NOT EXISTS hr_assignment_id UUID;
        
        RAISE NOTICE 'Added HR columns to employees table';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error adding HR columns to employees: %', SQLERRM;
    END;

    -- Add HR integration to vendors table
    BEGIN
        ALTER TABLE vendors
        ADD COLUMN IF NOT EXISTS hr_managed_by_employee_id UUID,
        ADD COLUMN IF NOT EXISTS hr_assigned_branch_id UUID;
        
        RAISE NOTICE 'Added HR columns to vendors table';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error adding HR columns to vendors: %', SQLERRM;
    END;

    -- Add HR integration to users table
    BEGIN
        ALTER TABLE users
        ADD COLUMN IF NOT EXISTS hr_employee_id UUID;
        
        RAISE NOTICE 'Added HR column to users table';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Error adding HR column to users: %', SQLERRM;
    END;
END $$;

-- =====================================================
-- STEP 2: CREATE FOREIGN KEY CONSTRAINTS
-- =====================================================
DO $$
BEGIN
    -- Add foreign key constraints if tables exist
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'hr_employees') THEN
        -- employees -> hr_employees
        BEGIN
            ALTER TABLE employees 
            DROP CONSTRAINT IF EXISTS fk_employees_hr_employee,
            ADD CONSTRAINT fk_employees_hr_employee 
            FOREIGN KEY (hr_employee_id) REFERENCES hr_employees(id);
            RAISE NOTICE 'Added employees -> hr_employees foreign key';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not add employees -> hr_employees foreign key: %', SQLERRM;
        END;
        
        -- users -> hr_employees
        BEGIN
            ALTER TABLE users
            DROP CONSTRAINT IF EXISTS fk_users_hr_employee,
            ADD CONSTRAINT fk_users_hr_employee
            FOREIGN KEY (hr_employee_id) REFERENCES hr_employees(id);
            RAISE NOTICE 'Added users -> hr_employees foreign key';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not add users -> hr_employees foreign key: %', SQLERRM;
        END;
        
        -- vendors -> hr_employees
        BEGIN
            ALTER TABLE vendors
            DROP CONSTRAINT IF EXISTS fk_vendors_hr_employee,
            ADD CONSTRAINT fk_vendors_hr_employee
            FOREIGN KEY (hr_managed_by_employee_id) REFERENCES hr_employees(id);
            RAISE NOTICE 'Added vendors -> hr_employees foreign key';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not add vendors -> hr_employees foreign key: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'HR tables not found - foreign keys will be added when HR system is created';
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'hr_positions') THEN
        -- employees -> hr_positions
        BEGIN
            ALTER TABLE employees
            DROP CONSTRAINT IF EXISTS fk_employees_hr_position,
            ADD CONSTRAINT fk_employees_hr_position
            FOREIGN KEY (hr_position_id) REFERENCES hr_positions(id);
            RAISE NOTICE 'Added employees -> hr_positions foreign key';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not add employees -> hr_positions foreign key: %', SQLERRM;
        END;
    END IF;
    
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'hr_position_assignments') THEN
        -- employees -> hr_position_assignments
        BEGIN
            ALTER TABLE employees
            DROP CONSTRAINT IF EXISTS fk_employees_hr_assignment,
            ADD CONSTRAINT fk_employees_hr_assignment
            FOREIGN KEY (hr_assignment_id) REFERENCES hr_position_assignments(id);
            RAISE NOTICE 'Added employees -> hr_position_assignments foreign key';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Could not add employees -> hr_position_assignments foreign key: %', SQLERRM;
        END;
    END IF;
END $$;

-- =====================================================
-- STEP 3: CREATE INTEGRATION VIEWS
-- =====================================================

-- Complete Employee View (combines HR and existing employee data)
CREATE OR REPLACE VIEW v_employees_complete AS
SELECT 
    e.id as employee_id,
    e.name as employee_name,
    e.email,
    e.phone,
    COALESCE(e.status, 'active') as employee_status,
    e.hire_date,
    e.salary,
    -- Branch information
    b.id as branch_id,
    COALESCE(b.name_en, b.name) as branch_name,
    COALESCE(b.name_ar, b.name) as branch_name_ar,
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
    COALESCE(v.payment_terms, 'Net 30') as payment_terms,
    -- HR Management data
    hr_e.employee_id as managed_by_employee_code,
    hr_e.name as managed_by_employee_name,
    hr_p.position_title_en as manager_position,
    -- Branch assignment
    COALESCE(b.name_en, b.name) as assigned_branch_name,
    COALESCE(b.location_en, b.address, b.region) as branch_location
FROM vendors v
LEFT JOIN hr_employees hr_e ON v.hr_managed_by_employee_id = hr_e.id
LEFT JOIN hr_position_assignments hr_pa ON hr_e.id = hr_pa.employee_id AND hr_pa.is_current = true
LEFT JOIN hr_positions hr_p ON hr_pa.position_id = hr_p.id
LEFT JOIN branches b ON COALESCE(v.hr_assigned_branch_id, v.branch_id) = b.id;

-- Organizational Chart View (only if HR tables exist)
CREATE OR REPLACE VIEW v_organizational_chart AS
SELECT 
    COALESCE(sub_pos.position_title_en, 'Unknown Position') as position,
    COALESCE(sub_pos.position_title_ar, 'منصب غير معروف') as position_ar,
    COALESCE(sub_dept.department_name_en, 'Unknown Department') as department,
    COALESCE(sub_level.level_name_en, 'Unknown Level') as level_name,
    COALESCE(sub_level.level_order, 0) as level_order,
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

-- =====================================================
-- STEP 4: CREATE INTEGRATION FUNCTIONS
-- =====================================================

-- Function to sync existing employee with HR system
CREATE OR REPLACE FUNCTION sync_employee_with_hr(
    p_employee_id UUID,
    p_employee_code VARCHAR(10),
    p_employee_name VARCHAR(200),
    p_branch_id UUID DEFAULT NULL,
    p_position_title VARCHAR(100) DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_hr_employee_id UUID;
    v_position_id UUID;
    v_assignment_id UUID;
BEGIN
    -- Check if HR tables exist
    IF NOT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'hr_employees') THEN
        RAISE EXCEPTION 'HR tables not found. Please create HR Master schema first.';
    END IF;
    
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

-- =====================================================
-- STEP 5: VERIFICATION AND SUMMARY
-- =====================================================

-- Check integration status
DO $$
DECLARE
    emp_count INTEGER := 0;
    vendor_count INTEGER := 0;
    user_count INTEGER := 0;
    hr_tables_exist BOOLEAN := false;
BEGIN
    -- Check if tables exist and count records
    SELECT COUNT(*) INTO emp_count FROM employees;
    SELECT COUNT(*) INTO vendor_count FROM vendors;
    SELECT COUNT(*) INTO user_count FROM users;
    
    -- Check if HR tables exist
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'hr_employees'
    ) INTO hr_tables_exist;
    
    RAISE NOTICE '=== INTEGRATION SUMMARY ===';
    RAISE NOTICE 'Employees table: % records', emp_count;
    RAISE NOTICE 'Vendors table: % records', vendor_count;
    RAISE NOTICE 'Users table: % records', user_count;
    RAISE NOTICE 'HR tables exist: %', CASE WHEN hr_tables_exist THEN 'YES' ELSE 'NO' END;
    
    IF hr_tables_exist THEN
        RAISE NOTICE 'HR integration columns added successfully!';
        RAISE NOTICE 'Views created: v_employees_complete, v_vendors_complete, v_organizational_chart';
        RAISE NOTICE 'Function created: sync_employee_with_hr()';
    ELSE
        RAISE NOTICE 'HR tables not found. Integration columns added, ready for HR schema.';
    END IF;
END $$;

-- Show available views
SELECT 
    'Available Views' as info,
    schemaname,
    viewname,
    'SELECT * FROM ' || schemaname || '.' || viewname || ' LIMIT 5;' as sample_query
FROM pg_views 
WHERE viewname LIKE 'v_%_complete' OR viewname LIKE 'v_organizational%'
ORDER BY viewname;

-- Final success message
SELECT 
    '🎉 HR MASTER INTEGRATION COMPLETED!' as status,
    'Your existing tables are now ready for HR Master system' as message,
    'Use sync_employee_with_hr() function to connect existing employees' as next_step;