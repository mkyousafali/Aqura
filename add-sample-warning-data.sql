-- =====================================================
-- Add Sample Warning Data for Testing
-- This script adds test warning records to verify the system works
-- =====================================================

-- First, let's see what users and employees exist to use for testing
SELECT 'AVAILABLE USERS' as type, id, username FROM users LIMIT 5;
SELECT 'AVAILABLE EMPLOYEES' as type, id, name, employee_id FROM hr_employees LIMIT 5;

-- =====================================================
-- Insert Sample Warning Records
-- =====================================================

-- Sample Warning 1: Performance warning without fine
INSERT INTO employee_warnings (
    user_id,
    employee_id,
    username,
    warning_type,
    warning_text,
    language_code,
    issued_by,
    issued_by_username,
    warning_status,
    severity_level,
    has_fine,
    total_tasks_assigned,
    total_tasks_completed,
    total_tasks_overdue,
    completion_rate
) VALUES (
    'e9f184e8-b85a-4834-b248-29c4e5ff4494',  -- User ID (shamsu)
    '62822d10-b910-4713-965f-63bd249b8b09',  -- Employee ID
    'shamsu',
    'overall_performance_no_fine',
    'Performance review indicates need for improvement in task completion rates. Employee shows potential but requires better time management and attention to detail.',
    'en',
    'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',  -- Master admin ID
    'madmin',
    'active',
    'medium',
    false,
    10,
    6,
    3,
    60.00
);

-- Sample Warning 2: Performance warning with fine
INSERT INTO employee_warnings (
    user_id,
    employee_id,
    username,
    warning_type,
    warning_text,
    language_code,
    issued_by,
    issued_by_username,
    warning_status,
    severity_level,
    has_fine,
    fine_amount,
    fine_currency,
    fine_status,
    fine_due_date,
    total_tasks_assigned,
    total_tasks_completed,
    total_tasks_overdue,
    completion_rate
) VALUES (
    'e9f184e8-b85a-4834-b248-29c4e5ff4494',  -- User ID (shamsu)
    '62822d10-b910-4713-965f-63bd249b8b09',  -- Employee ID
    'shamsu',
    'overall_performance_with_fine',
    'Repeated performance issues with task completion. This is a formal warning with monetary penalty due to failure to meet established performance standards.',
    'en',
    'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',  -- Master admin ID
    'madmin',
    'active',
    'high',
    true,
    150.00,
    'USD',
    'pending',
    CURRENT_DATE + INTERVAL '30 days',
    15,
    8,
    5,
    53.33
);

-- Sample Warning 3: Task-specific warning
INSERT INTO employee_warnings (
    user_id,
    employee_id,
    username,
    warning_type,
    warning_text,
    language_code,
    issued_by,
    issued_by_username,
    warning_status,
    severity_level,
    has_fine,
    task_title,
    task_description,
    total_tasks_assigned,
    total_tasks_completed,
    total_tasks_overdue,
    completion_rate
) VALUES (
    'e9f184e8-b85a-4834-b248-29c4e5ff4494',  -- User ID (shamsu)
    '62822d10-b910-4713-965f-63bd249b8b09',  -- Employee ID
    'shamsu',
    'task_specific_no_fine',
    'Specific warning regarding the Customer Database Update project. Task was not completed within the specified timeframe and quality standards were not met.',
    'en',
    'e1fdaee2-97f0-4fc1-872f-9d99c6bd684b',  -- Master admin ID
    'madmin',
    'acknowledged',
    'medium',
    false,
    'Customer Database Update',
    'Update customer contact information and verify data accuracy',
    5,
    4,
    1,
    80.00
);

-- =====================================================
-- Verify the sample data was inserted
-- =====================================================

SELECT 
    'INSERTED WARNINGS' as status,
    count(*) as total_warnings
FROM employee_warnings 
WHERE is_deleted = false;

-- Show the sample warnings
SELECT 
    id,
    username,
    warning_type,
    warning_status,
    severity_level,
    has_fine,
    fine_amount,
    warning_reference,
    issued_at
FROM employee_warnings 
WHERE is_deleted = false
ORDER BY issued_at DESC;

-- Check warning history was created
SELECT 
    'WARNING HISTORY' as status,
    count(*) as history_records
FROM employee_warning_history;

-- Show warning details with employee info (test the query that frontend uses)
SELECT 
    w.*,
    u.username as user_username,
    e.name as employee_name,
    e.employee_id as employee_code
FROM employee_warnings w
LEFT JOIN users u ON w.user_id = u.id
LEFT JOIN hr_employees e ON w.employee_id = e.id
WHERE w.is_deleted = false
ORDER BY w.issued_at DESC;

-- =====================================================
-- Summary
-- =====================================================

SELECT 
    'SAMPLE DATA READY' as status,
    'You can now test the Warning Records view functionality' as message,
    'Click the View button to see warning details' as next_step;