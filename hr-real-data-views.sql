-- =====================================================
-- UPDATED HR INTEGRATION VIEWS - USING REAL SUPABASE DATA
-- Run this AFTER hr-real-data-migration.sql
-- =====================================================

-- =====================================================
-- UPDATED VIEWS FOR REAL DATA
-- =====================================================

-- Enhanced Complete Employee View with better real data handling
CREATE OR REPLACE VIEW v_employees_complete AS
SELECT 
    e.id as employee_id,
    e.name as employee_name,
    e.email,
    e.phone,
    COALESCE(e.status, 'active') as employee_status,
    e.hire_date,
    e.salary as original_salary,
    e.position as original_position,
    e.department as original_department,
    
    -- Branch information (flexible column handling)
    b.id as branch_id,
    COALESCE(b.name_en, b.name) as branch_name,
    COALESCE(b.name_ar, b.name, 'فرع') as branch_name_ar,
    COALESCE(b.location_en, b.address, b.region) as branch_location,
    
    -- HR Master data
    hr_e.employee_id as hr_employee_code,
    hr_e.name as hr_name,
    hr_e.status as hr_status,
    hr_p.position_title_en as hr_position_title,
    hr_p.position_title_ar as hr_position_title_ar,
    hr_d.department_name_en as hr_department_name,
    hr_d.department_name_ar as hr_department_name_ar,
    hr_l.level_name_en as hr_level_name,
    hr_l.level_order as hierarchy_level,
    
    -- Position assignment info
    hr_pa.assigned_date,
    hr_pa.is_current as current_assignment,
    
    -- Salary info from HR system
    hr_sw.basic_salary as hr_basic_salary,
    hr_sw.effective_date as salary_effective_date,
    
    -- Contact info from HR system
    STRING_AGG(CASE WHEN hc.contact_type = 'email' THEN hc.contact_value END, ', ') as hr_emails,
    STRING_AGG(CASE WHEN hc.contact_type = 'phone' THEN hc.contact_value END, ', ') as hr_phones
    
FROM employees e
LEFT JOIN branches b ON e.branch_id = b.id
LEFT JOIN hr_employees hr_e ON e.hr_employee_id = hr_e.id
LEFT JOIN hr_position_assignments hr_pa ON e.hr_assignment_id = hr_pa.id
LEFT JOIN hr_positions hr_p ON hr_pa.position_id = hr_p.id
LEFT JOIN hr_departments hr_d ON hr_p.department_id = hr_d.id
LEFT JOIN hr_levels hr_l ON hr_p.level_id = hr_l.id
LEFT JOIN hr_salary_wages hr_sw ON hr_e.id = hr_sw.employee_id AND hr_sw.is_current = true
LEFT JOIN hr_employee_contacts hc ON hr_e.id = hc.employee_id
GROUP BY e.id, e.name, e.email, e.phone, e.status, e.hire_date, e.salary, e.position, e.department,
         b.id, b.name_en, b.name, b.name_ar, b.location_en, b.address, b.region,
         hr_e.employee_id, hr_e.name, hr_e.status, hr_p.position_title_en, hr_p.position_title_ar,
         hr_d.department_name_en, hr_d.department_name_ar, hr_l.level_name_en, hr_l.level_order,
         hr_pa.assigned_date, hr_pa.is_current, hr_sw.basic_salary, hr_sw.effective_date;

-- Enhanced Vendor View with real data handling
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
    
    -- Original branch info
    ob.id as original_branch_id,
    COALESCE(ob.name_en, ob.name) as original_branch_name,
    
    -- HR Management data
    hr_e.employee_id as managed_by_employee_code,
    hr_e.name as managed_by_employee_name,
    hr_p.position_title_en as manager_position,
    hr_p.position_title_ar as manager_position_ar,
    hr_l.level_name_en as manager_level,
    
    -- HR assigned branch info
    hb.id as hr_assigned_branch_id,
    COALESCE(hb.name_en, hb.name) as hr_assigned_branch_name,
    COALESCE(hb.location_en, hb.address, hb.region) as hr_branch_location,
    
    -- Manager contact info
    STRING_AGG(CASE WHEN hc.contact_type = 'email' THEN hc.contact_value END, ', ') as manager_emails,
    STRING_AGG(CASE WHEN hc.contact_type = 'phone' THEN hc.contact_value END, ', ') as manager_phones
    
FROM vendors v
LEFT JOIN branches ob ON v.branch_id = ob.id
LEFT JOIN hr_employees hr_e ON v.hr_managed_by_employee_id = hr_e.id
LEFT JOIN hr_position_assignments hr_pa ON hr_e.id = hr_pa.employee_id AND hr_pa.is_current = true
LEFT JOIN hr_positions hr_p ON hr_pa.position_id = hr_p.id
LEFT JOIN hr_levels hr_l ON hr_p.level_id = hr_l.id
LEFT JOIN branches hb ON v.hr_assigned_branch_id = hb.id
LEFT JOIN hr_employee_contacts hc ON hr_e.id = hc.employee_id
GROUP BY v.id, v.name, v.company, v.email, v.phone, v.category, v.status, v.payment_terms,
         ob.id, ob.name_en, ob.name, hr_e.employee_id, hr_e.name, hr_p.position_title_en, hr_p.position_title_ar,
         hr_l.level_name_en, hb.id, hb.name_en, hb.name, hb.location_en, hb.address, hb.region;

-- Real Data Organizational Chart with Current Assignments
CREATE OR REPLACE VIEW v_organizational_chart_real AS
SELECT 
    sub_pos.position_title_en as position,
    sub_pos.position_title_ar as position_ar,
    sub_dept.department_name_en as department,
    sub_level.level_name_en as level_name,
    sub_level.level_order,
    
    -- Current employee in this position (real data)
    hr_e.employee_id as employee_code,
    hr_e.name as employee_name,
    hr_e.status as employee_status,
    hr_e.hire_date,
    
    -- Original employee data
    orig_e.name as original_name,
    orig_e.email as original_email,
    orig_e.position as original_position,
    
    -- Branch information
    COALESCE(b.name_en, b.name) as branch_name,
    
    -- Manager information
    mgr1_pos.position_title_en as reports_to_1,
    mgr2_pos.position_title_en as reports_to_2,
    mgr3_pos.position_title_en as reports_to_3,
    
    -- Salary information
    hr_sw.basic_salary,
    
    -- Current assignments count
    (SELECT COUNT(*) FROM hr_position_assignments 
     WHERE position_id = sub_pos.id AND is_current = true) as current_employees
     
FROM hr_position_reporting_template rt
JOIN hr_positions sub_pos ON rt.subordinate_position_id = sub_pos.id
JOIN hr_departments sub_dept ON sub_pos.department_id = sub_dept.id
JOIN hr_levels sub_level ON sub_pos.level_id = sub_level.id
LEFT JOIN hr_positions mgr1_pos ON rt.manager_position_1 = mgr1_pos.id
LEFT JOIN hr_positions mgr2_pos ON rt.manager_position_2 = mgr2_pos.id
LEFT JOIN hr_positions mgr3_pos ON rt.manager_position_3 = mgr3_pos.id

-- Get current employee assignment (real data)
LEFT JOIN hr_position_assignments hr_pa ON sub_pos.id = hr_pa.position_id AND hr_pa.is_current = true
LEFT JOIN hr_employees hr_e ON hr_pa.employee_id = hr_e.id
LEFT JOIN employees orig_e ON orig_e.hr_employee_id = hr_e.id
LEFT JOIN branches b ON hr_e.branch_id = b.id
LEFT JOIN hr_salary_wages hr_sw ON hr_e.id = hr_sw.employee_id AND hr_sw.is_current = true

ORDER BY sub_level.level_order, sub_dept.department_name_en, sub_pos.position_title_en;

-- Branch Employee Summary with Real Data
CREATE OR REPLACE VIEW v_branch_employee_summary_real AS
SELECT 
    b.id as branch_id,
    COALESCE(b.name_en, b.name) as branch_name,
    COALESCE(b.name_ar, b.name, 'فرع') as branch_name_ar,
    COALESCE(b.location_en, b.address, b.region, 'Location') as location,
    
    -- Employee counts by level (real data)
    COUNT(CASE WHEN hr_l.level_order = 1 THEN 1 END) as executive_count,
    COUNT(CASE WHEN hr_l.level_order = 2 THEN 1 END) as senior_mgmt_count,
    COUNT(CASE WHEN hr_l.level_order = 3 THEN 1 END) as core_mgmt_count,
    COUNT(CASE WHEN hr_l.level_order = 4 THEN 1 END) as quality_count,
    COUNT(CASE WHEN hr_l.level_order = 5 THEN 1 END) as branch_mgmt_count,
    COUNT(CASE WHEN hr_l.level_order = 6 THEN 1 END) as dept_heads_count,
    COUNT(CASE WHEN hr_l.level_order = 7 THEN 1 END) as supervisors_count,
    COUNT(CASE WHEN hr_l.level_order = 8 THEN 1 END) as staff_count,
    COUNT(hr_e.id) as total_hr_employees,
    
    -- Original employee counts
    (SELECT COUNT(*) FROM employees WHERE branch_id = b.id) as total_original_employees,
    
    -- Salary totals by level (real data)
    SUM(CASE WHEN hr_l.level_order <= 3 THEN COALESCE(hr_sw.basic_salary, 0) ELSE 0 END) as management_salary_total,
    SUM(COALESCE(hr_sw.basic_salary, 0)) as total_hr_salary_cost,
    
    -- Original salary totals
    (SELECT SUM(COALESCE(salary, 0)) FROM employees WHERE branch_id = b.id) as total_original_salary_cost
    
FROM branches b
LEFT JOIN hr_employees hr_e ON b.id = hr_e.branch_id
LEFT JOIN hr_position_assignments hr_pa ON hr_e.id = hr_pa.employee_id AND hr_pa.is_current = true
LEFT JOIN hr_positions hr_p ON hr_pa.position_id = hr_p.id
LEFT JOIN hr_levels hr_l ON hr_p.level_id = hr_l.id
LEFT JOIN hr_salary_wages hr_sw ON hr_e.id = hr_sw.employee_id AND hr_sw.is_current = true
GROUP BY b.id, b.name_en, b.name, b.name_ar, b.location_en, b.address, b.region
ORDER BY COALESCE(b.name_en, b.name);

-- Employee Performance Summary (combining original and HR data)
CREATE OR REPLACE VIEW v_employee_performance_summary AS
SELECT 
    orig_e.id as original_employee_id,
    orig_e.name as employee_name,
    orig_e.email,
    orig_e.hire_date,
    orig_e.salary as original_salary,
    orig_e.position as original_position,
    
    -- HR data
    hr_e.employee_id as hr_code,
    hr_p.position_title_en as hr_position,
    hr_d.department_name_en as hr_department,
    hr_l.level_name_en as hr_level,
    hr_l.level_order,
    hr_sw.basic_salary as hr_salary,
    
    -- Branch info
    COALESCE(b.name_en, b.name) as branch_name,
    
    -- Performance indicators
    CASE 
        WHEN orig_e.salary IS NOT NULL AND hr_sw.basic_salary IS NOT NULL THEN 
            ROUND(((hr_sw.basic_salary - orig_e.salary) / orig_e.salary::DECIMAL * 100), 2)
        ELSE NULL
    END as salary_change_percent,
    
    -- Status comparison
    CASE 
        WHEN orig_e.status = hr_e.status THEN 'Consistent'
        ELSE 'Different: ' || COALESCE(orig_e.status, 'NULL') || ' vs ' || COALESCE(hr_e.status, 'NULL')
    END as status_comparison,
    
    -- Assignment info
    hr_pa.assigned_date,
    EXTRACT(DAYS FROM NOW() - hr_pa.assigned_date) as days_in_current_position
    
FROM employees orig_e
LEFT JOIN hr_employees hr_e ON orig_e.hr_employee_id = hr_e.id
LEFT JOIN hr_position_assignments hr_pa ON hr_e.id = hr_pa.employee_id AND hr_pa.is_current = true
LEFT JOIN hr_positions hr_p ON hr_pa.position_id = hr_p.id
LEFT JOIN hr_departments hr_d ON hr_p.department_id = hr_d.id
LEFT JOIN hr_levels hr_l ON hr_p.level_id = hr_l.id
LEFT JOIN hr_salary_wages hr_sw ON hr_e.id = hr_sw.employee_id AND hr_sw.is_current = true
LEFT JOIN branches b ON orig_e.branch_id = b.id
ORDER BY hr_l.level_order, COALESCE(b.name_en, b.name), orig_e.name;

-- =====================================================
-- REAL DATA HELPER FUNCTIONS
-- =====================================================

-- Function to sync updated employee data
CREATE OR REPLACE FUNCTION sync_updated_employee_data() RETURNS TEXT AS $$
DECLARE
    sync_count INTEGER := 0;
    emp_record RECORD;
BEGIN
    -- Update HR employees with any changes from original employees
    FOR emp_record IN 
        SELECT 
            e.id, e.name, e.email, e.phone, e.salary, e.status, e.position,
            hr_e.id as hr_id, hr_e.name as hr_name
        FROM employees e
        JOIN hr_employees hr_e ON e.hr_employee_id = hr_e.id
        WHERE e.name != hr_e.name OR 
              e.status != hr_e.status OR
              NOT EXISTS (
                  SELECT 1 FROM hr_salary_wages 
                  WHERE employee_id = hr_e.id AND basic_salary = e.salary AND is_current = true
              )
    LOOP
        -- Update HR employee record
        UPDATE hr_employees 
        SET name = emp_record.name,
            status = emp_record.status,
            updated_at = NOW()
        WHERE id = emp_record.hr_id;
        
        -- Update salary if different
        IF emp_record.salary IS NOT NULL THEN
            -- End current salary record
            UPDATE hr_salary_wages 
            SET is_current = false, end_date = NOW()
            WHERE employee_id = emp_record.hr_id AND is_current = true;
            
            -- Create new salary record
            INSERT INTO hr_salary_wages (employee_id, basic_salary, effective_date, is_current)
            VALUES (emp_record.hr_id, emp_record.salary, NOW(), true);
        END IF;
        
        sync_count := sync_count + 1;
    END LOOP;
    
    RETURN 'Synchronized ' || sync_count || ' employee records with updated data';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- DATA QUALITY CHECKS
-- =====================================================

-- View to show data quality and completeness
CREATE OR REPLACE VIEW v_data_quality_report AS
SELECT 
    'Original Employees' as data_source,
    COUNT(*) as total_records,
    COUNT(CASE WHEN name IS NOT NULL AND name != '' THEN 1 END) as has_name,
    COUNT(CASE WHEN email IS NOT NULL AND email != '' THEN 1 END) as has_email,
    COUNT(CASE WHEN phone IS NOT NULL AND phone != '' THEN 1 END) as has_phone,
    COUNT(CASE WHEN salary IS NOT NULL AND salary > 0 THEN 1 END) as has_salary,
    COUNT(CASE WHEN hr_employee_id IS NOT NULL THEN 1 END) as linked_to_hr
FROM employees

UNION ALL

SELECT 
    'HR Employees' as data_source,
    COUNT(*) as total_records,
    COUNT(CASE WHEN name IS NOT NULL AND name != '' THEN 1 END) as has_name,
    0 as has_email, -- HR contacts are separate
    0 as has_phone, -- HR contacts are separate
    COUNT(CASE WHEN EXISTS (SELECT 1 FROM hr_salary_wages WHERE employee_id = hr_employees.id AND is_current = true) THEN 1 END) as has_salary,
    COUNT(*) as linked_to_hr -- All HR employees are linked by definition
FROM hr_employees

UNION ALL

SELECT 
    'Vendors' as data_source,
    COUNT(*) as total_records,
    COUNT(CASE WHEN name IS NOT NULL AND name != '' THEN 1 END) as has_name,
    COUNT(CASE WHEN email IS NOT NULL AND email != '' THEN 1 END) as has_email,
    COUNT(CASE WHEN phone IS NOT NULL AND phone != '' THEN 1 END) as has_phone,
    0 as has_salary, -- Not applicable
    COUNT(CASE WHEN hr_managed_by_employee_id IS NOT NULL THEN 1 END) as linked_to_hr
FROM vendors;

-- Success message
SELECT 
    '✅ UPDATED VIEWS CREATED WITH REAL DATA!' as status,
    'All views now use your actual Supabase data instead of mock data' as message,
    'Views: v_employees_complete, v_vendors_complete, v_organizational_chart_real, etc.' as available_views;