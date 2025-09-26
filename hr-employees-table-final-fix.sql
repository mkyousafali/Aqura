-- =====================================================
-- FINAL FIX FOR HR EMPLOYEES TABLE
-- Simplified structure for Upload Employees function
-- =====================================================

-- Update hr_employees table to match Upload Employees function requirements
ALTER TABLE hr_employees 
    ALTER COLUMN hire_date DROP NOT NULL; -- Make hire_date optional since it's updated later

-- Update table comment
COMMENT ON TABLE hr_employees IS 'HR Employees - Upload function with Employee ID and Name only. Branch assigned from UI, Hire Date updated later.';

-- =====================================================
-- VERIFICATION QUERY
-- =====================================================

-- Check updated structure
SELECT column_name, data_type, is_nullable, character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'hr_employees' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- =====================================================
-- SIMPLIFIED UPLOAD EMPLOYEES EXCEL TEMPLATE
-- =====================================================

-- Template Format:
-- Employee ID | Name              
-- 1          | Ahmed Mohammed    
-- 25         | Sarah Ali         
-- 120        | Omar Hassan       
-- 1251       | Fatima Ahmed      

-- Processing Flow:
-- 1. User selects branch in UI
-- 2. User uploads Excel with only Employee ID and Name
-- 3. System assigns branch_id automatically based on UI selection
-- 4. Hire date remains NULL until updated via another HR function
-- 5. Status defaults to 'active'