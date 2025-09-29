-- Test Employee Data for Branch Employee Selection
-- This script adds sample employees to test the user management functionality

-- First, check existing branches
SELECT id, name_en, name_ar FROM branches WHERE is_active = true ORDER BY id;

-- Add sample employees to hr_employees table
-- Note: Using branch_id = 1 assuming there's a branch with id 1
INSERT INTO hr_employees (employee_id, name, branch_id) 
VALUES 
    ('EMP001', 'Ahmed Mohammed Ali', 1),
    ('EMP002', 'Fatima Hassan Ibrahim', 1),
    ('EMP003', 'Omar Khalil Mahmoud', 1),
    ('EMP004', 'Aisha Ahmed Youssef', 2),
    ('EMP005', 'Mohammed Ali Hassan', 2)
ON CONFLICT (employee_id) DO UPDATE SET
    name = EXCLUDED.name,
    branch_id = EXCLUDED.branch_id;

-- Verify the data was inserted
SELECT 
    e.id,
    e.employee_id,
    e.name,
    e.branch_id,
    b.name_en as branch_name
FROM hr_employees e
LEFT JOIN branches b ON e.branch_id = b.id
ORDER BY e.branch_id, e.name;

-- Check if there are any positions to assign
SELECT id, position_title_en FROM hr_positions LIMIT 5;