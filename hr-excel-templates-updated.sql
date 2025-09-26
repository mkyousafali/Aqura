-- =====================================================
-- EXCEL TEMPLATES FOR HR FUNCTIONS
-- Updated templates to match consistent employee_id format
-- =====================================================

-- =====================================================
-- 1. UPLOAD EMPLOYEES EXCEL TEMPLATE
-- =====================================================

-- Template Format:
-- Columns: Employee ID | Name | Branch | Hire Date

-- Sample Data:
-- Employee ID  | Name              | Branch    | Hire Date
-- 1           | Ahmed Mohammed    | Main      | 2024-01-15
-- 25          | Sarah Ali         | Branch 2  | 2024-02-20
-- 120         | Omar Hassan       | Branch 3  | 2024-03-10
-- 1251        | Fatima Ahmed      | Main      | 2024-04-05

-- Column Details:
-- Employee ID: Numeric values (1, 25, 120, 1251, etc.)
-- Name: Full employee name (VARCHAR 200)
-- Branch: Branch name or identifier
-- Hire Date: Format YYYY-MM-DD (2024-01-15)

-- =====================================================
-- 2. UPLOAD FINGERPRINT EXCEL TEMPLATE
-- =====================================================

-- Template Format:
-- Columns: Employee ID | Name | Date | Time | Punch State

-- Sample Data:
-- Employee ID  | Name              | Date       | Time     | Punch State
-- 1           | Ahmed Mohammed    | 2024-09-25 | 08:00 AM | Check In
-- 1           | Ahmed Mohammed    | 2024-09-25 | 05:30 PM | Check Out
-- 25          | Sarah Ali         | 2024-09-25 | 09:15 AM | Check In
-- 25          | Sarah Ali         | 2024-09-25 | 06:00 PM | Check Out
-- 120         | Omar Hassan       | 2024-09-25 | 08:45 AM | Check In
-- 120         | Omar Hassan       | 2024-09-25 | 05:15 PM | Check Out
-- 1251        | Fatima Ahmed      | 2024-09-26 | 08:30 AM | Check In

-- Column Details:
-- Employee ID: Numeric values (1, 25, 120, 1251, etc.) - MUST MATCH hr_employees table
-- Name: Full employee name (VARCHAR 200) - MUST MATCH hr_employees table  
-- Date: Format YYYY-MM-DD (2024-09-25)
-- Time: Format HH:MM AM/PM (08:00 AM, 05:30 PM)
-- Punch State: Either "Check In" or "Check Out" (exact text)

-- =====================================================
-- TEMPLATE VALIDATION RULES
-- =====================================================

-- 1. Employee ID Consistency:
--    - Both templates use same numeric employee_id format
--    - No prefixes like "EMP" or "AQ-2024"
--    - Just plain numbers: 1, 25, 120, 1251

-- 2. Name Consistency:
--    - Both templates use same name field
--    - Employee names should match between upload functions
--    - Helps with data validation and linking

-- 3. Data Types:
--    - Employee ID: VARCHAR(10) - handles up to 9999999999
--    - Name: VARCHAR(200) - handles long names
--    - Date: DATE format (YYYY-MM-DD)
--    - Time: TIME format (HH:MM AM/PM)

-- =====================================================
-- EXCEL FILE GENERATION NOTES
-- =====================================================

-- For Upload Employees Template:
-- - Create Excel with headers: Employee ID, Name, Branch, Hire Date
-- - Include sample rows with numeric IDs
-- - Format Hire Date column as Date

-- For Upload Fingerprint Template:
-- - Create Excel with headers: Employee ID, Name, Date, Time, Punch State
-- - Include sample rows with numeric IDs
-- - Format Date column as Date
-- - Format Time column as Time with AM/PM
-- - Punch State dropdown: "Check In", "Check Out"

-- =====================================================