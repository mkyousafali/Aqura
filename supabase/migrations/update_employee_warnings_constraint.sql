-- Migration: Update employee_warnings table to support task-specific warning types
-- This adds the new task-specific warning types to the warning_type constraint

-- Drop the existing check constraint
ALTER TABLE employee_warnings 
DROP CONSTRAINT IF EXISTS employee_warnings_warning_type_check;

-- Add the updated check constraint with task-specific warning types
ALTER TABLE employee_warnings 
ADD CONSTRAINT employee_warnings_warning_type_check 
CHECK (warning_type IN (
    -- Original performance-based warning types
    'overall_performance_no_fine',
    'overall_performance_fine_threat',
    'overall_performance_with_fine',
    -- New task-specific warning types
    'task_delay_no_fine',
    'task_delay_fine_threat',
    'task_delay_with_fine',
    'task_incomplete_no_fine',
    'task_quality_issue'
));

-- Add comment explaining the warning types
COMMENT ON CONSTRAINT employee_warnings_warning_type_check ON employee_warnings IS 
'Validates warning types: performance-based (overall_performance_*) for general employee performance issues, and task-specific (task_*) for individual task delays, incompletions, or quality issues. Each can have no_fine, fine_threat, or with_fine variants.';
