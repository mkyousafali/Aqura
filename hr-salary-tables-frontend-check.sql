-- =====================================================
-- HR SALARY TABLES - FRONTEND ALIGNMENT CHECK
-- =====================================================

-- Check current salary tables structure
SELECT 'hr_salary_wages' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'hr_salary_wages' 
AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'hr_salary_components' as table_name, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'hr_salary_components' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- =====================================================
-- FRONTEND FORM ANALYSIS
-- =====================================================

-- From the frontend form image, I can see:
-- 1. BASIC INFORMATIONS section (separate from salary)
-- 2. SALARY INFORMATIONS section with:
--    - Basic Salary field
--    - Allowances section (multiple allowances with amounts)
--    - Deductions section (multiple deductions with amounts)

-- =====================================================
-- PROPOSED STRUCTURE MATCHES FRONTEND:
-- =====================================================

-- hr_salary_wages table handles:
-- ✅ Basic Salary (matches "Basic Salary" field in frontend)
-- ✅ Employee reference
-- ✅ Effective dates

-- hr_salary_components table handles:
-- ✅ Allowances (multiple entries with component_type = 'ALLOWANCE')
-- ✅ Deductions (multiple entries with component_type = 'DEDUCTION') 
-- ✅ Component names and amounts
-- ✅ Enable/disable functionality
-- ✅ Application periods for deductions

-- =====================================================
-- VERIFICATION: Does this match your frontend exactly?
-- =====================================================

-- Sample data structure that would match frontend:

-- Employee Basic Salary:
-- INSERT INTO hr_salary_wages (employee_id, branch_id, basic_salary, effective_from)
-- VALUES ('employee-uuid', 'branch-uuid', 5000.00, '2024-01-01');

-- Employee Allowances:
-- INSERT INTO hr_salary_components (salary_id, employee_id, component_type, component_name, amount)
-- VALUES ('salary-uuid', 'employee-uuid', 'ALLOWANCE', 'Transportation', 300.00),
--        ('salary-uuid', 'employee-uuid', 'ALLOWANCE', 'Food', 200.00);

-- Employee Deductions:  
-- INSERT INTO hr_salary_components (salary_id, employee_id, component_type, component_name, amount)
-- VALUES ('salary-uuid', 'employee-uuid', 'DEDUCTION', 'Insurance', 150.00),
--        ('salary-uuid', 'employee-uuid', 'DEDUCTION', 'Tax', 500.00);