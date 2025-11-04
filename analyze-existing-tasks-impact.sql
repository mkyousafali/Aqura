-- =====================================================
-- ANALYZE EXISTING TASKS IMPACT
-- =====================================================
-- This SQL script checks how our new photo and dependency rules
-- will affect existing completed tasks
-- =====================================================

-- 1. Check current receiving_tasks table structure
SELECT 
    'TABLE STRUCTURE ANALYSIS' as analysis_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'receiving_tasks' 
  AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check if completion_photo_url column exists
SELECT 
    'PHOTO COLUMN CHECK' as analysis_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'receiving_tasks' 
              AND column_name = 'completion_photo_url'
        ) THEN 'Column EXISTS - Schema already updated'
        ELSE 'Column MISSING - Schema needs update'
    END as photo_column_status;

-- 3. Count existing completed tasks by role
SELECT 
    'COMPLETED TASKS BY ROLE' as analysis_type,
    role_type,
    COUNT(*) as total_completed,
    COUNT(CASE WHEN completion_photo_url IS NOT NULL THEN 1 END) as with_photo,
    COUNT(CASE WHEN completion_photo_url IS NULL THEN 1 END) as without_photo,
    MIN(completed_at) as earliest_completion,
    MAX(completed_at) as latest_completion
FROM receiving_tasks 
WHERE task_completed = true
GROUP BY role_type
ORDER BY total_completed DESC;

-- 4. Check shelf stocker tasks specifically
SELECT 
    'SHELF STOCKER ANALYSIS' as analysis_type,
    COUNT(*) as total_shelf_stocker_completed,
    COUNT(CASE WHEN completion_photo_url IS NOT NULL THEN 1 END) as with_photo,
    COUNT(CASE WHEN completion_photo_url IS NULL THEN 1 END) as without_photo,
    ROUND(
        COUNT(CASE WHEN completion_photo_url IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as percentage_with_photo
FROM receiving_tasks 
WHERE task_completed = true 
  AND role_type = 'shelf_stocker';

-- 5. Analyze receiving records with completed tasks
SELECT 
    'RECEIVING RECORD ANALYSIS' as analysis_type,
    COUNT(DISTINCT receiving_record_id) as total_records_with_completed_tasks,
    COUNT(DISTINCT CASE 
        WHEN role_type = 'shelf_stocker' 
        THEN receiving_record_id 
    END) as records_with_shelf_stocker_completed,
    COUNT(DISTINCT CASE 
        WHEN role_type = 'branch_manager' 
        THEN receiving_record_id 
    END) as records_with_branch_manager_completed,
    COUNT(DISTINCT CASE 
        WHEN role_type = 'night_supervisor' 
        THEN receiving_record_id 
    END) as records_with_night_supervisor_completed
FROM receiving_tasks 
WHERE task_completed = true;

-- 6. Check for potential dependency violations in existing data
WITH record_completions AS (
    SELECT 
        receiving_record_id,
        BOOL_OR(role_type = 'shelf_stocker' AND task_completed = true) as shelf_stocker_completed,
        BOOL_OR(role_type = 'branch_manager' AND task_completed = true) as branch_manager_completed,
        BOOL_OR(role_type = 'night_supervisor' AND task_completed = true) as night_supervisor_completed,
        BOOL_OR(
            role_type = 'shelf_stocker' 
            AND task_completed = true 
            AND completion_photo_url IS NOT NULL
        ) as shelf_stocker_has_photo
    FROM receiving_tasks
    GROUP BY receiving_record_id
)
SELECT 
    'DEPENDENCY VIOLATION ANALYSIS' as analysis_type,
    COUNT(*) as total_receiving_records,
    COUNT(CASE 
        WHEN (branch_manager_completed OR night_supervisor_completed) 
             AND NOT shelf_stocker_completed 
        THEN 1 
    END) as violations_no_shelf_stocker,
    COUNT(CASE 
        WHEN (branch_manager_completed OR night_supervisor_completed) 
             AND shelf_stocker_completed 
             AND NOT shelf_stocker_has_photo 
        THEN 1 
    END) as violations_no_photo,
    COUNT(CASE 
        WHEN shelf_stocker_completed 
             AND shelf_stocker_has_photo 
        THEN 1 
    END) as compliant_records
FROM record_completions;

-- 7. Sample records showing potential issues
SELECT 
    'SAMPLE PROBLEMATIC RECORDS' as analysis_type,
    r.receiving_record_id,
    STRING_AGG(
        CASE WHEN r.task_completed 
        THEN r.role_type || '(' || COALESCE(r.completed_at::text, 'unknown') || ')'
        END, 
        ', '
    ) as completed_roles,
    BOOL_OR(r.role_type = 'shelf_stocker' AND r.task_completed) as has_shelf_stocker,
    BOOL_OR(
        r.role_type = 'shelf_stocker' 
        AND r.task_completed 
        AND r.completion_photo_url IS NOT NULL
    ) as shelf_stocker_has_photo
FROM receiving_tasks r
GROUP BY r.receiving_record_id
HAVING 
    -- Records where dependent roles completed but shelf stocker didn't
    (BOOL_OR(r.role_type IN ('branch_manager', 'night_supervisor') AND r.task_completed) 
     AND NOT BOOL_OR(r.role_type = 'shelf_stocker' AND r.task_completed))
    OR
    -- Records where dependent roles completed but shelf stocker has no photo
    (BOOL_OR(r.role_type IN ('branch_manager', 'night_supervisor') AND r.task_completed) 
     AND BOOL_OR(r.role_type = 'shelf_stocker' AND r.task_completed) 
     AND NOT BOOL_OR(r.role_type = 'shelf_stocker' AND r.task_completed AND r.completion_photo_url IS NOT NULL))
LIMIT 10;

-- 8. Summary recommendations
SELECT 
    'IMPLEMENTATION RECOMMENDATIONS' as analysis_type,
    'STRATEGY: Grandfather existing completed tasks, enforce rules only for new tasks' as recommendation,
    'TECHNICAL: Add rule_effective_date column, check task.created_at vs effective_date' as implementation,
    'IMPACT: Existing tasks unchanged, new tasks follow photo/dependency rules' as impact;