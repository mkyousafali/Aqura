-- Comprehensive Missing Database Functions
-- This creates all the RPC functions that the frontend expects

-- Drop existing functions if they exist with different signatures
DROP FUNCTION IF EXISTS search_tasks(TEXT, TEXT, UUID, UUID);
DROP FUNCTION IF EXISTS get_task_statistics(UUID);
DROP FUNCTION IF EXISTS create_scheduled_assignment(UUID, UUID, UUID, TIMESTAMPTZ, VARCHAR);
DROP FUNCTION IF EXISTS create_recurring_assignment(UUID, UUID, UUID, VARCHAR, DATE, DATE);
DROP FUNCTION IF EXISTS reassign_task(UUID, UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS get_assignments_with_deadlines(UUID, INTEGER);

-- 1. Task management functions
CREATE OR REPLACE FUNCTION search_tasks(
    search_term TEXT DEFAULT NULL,
    task_status TEXT DEFAULT NULL,
    assigned_user_id UUID DEFAULT NULL,
    created_by_user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    title VARCHAR,
    description TEXT,
    status VARCHAR,
    priority VARCHAR,
    assigned_to UUID,
    created_by UUID,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    due_date DATE,
    assignee_name VARCHAR,
    creator_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.title,
        t.description,
        t.status,
        t.priority,
        ta.assigned_to,
        t.created_by,
        t.created_at,
        t.updated_at,
        t.due_date,
        COALESCE(u_assignee.username, 'Unassigned')::VARCHAR as assignee_name,
        COALESCE(u_creator.username, 'Unknown')::VARCHAR as creator_name
    FROM tasks t
    LEFT JOIN task_assignments ta ON t.id = ta.task_id
    LEFT JOIN users u_assignee ON ta.assigned_to = u_assignee.id
    LEFT JOIN users u_creator ON t.created_by = u_creator.id
    WHERE (search_term IS NULL OR t.title ILIKE '%' || search_term || '%' OR t.description ILIKE '%' || search_term || '%')
      AND (task_status IS NULL OR t.status = task_status)
      AND (assigned_user_id IS NULL OR ta.assigned_to = assigned_user_id)
      AND (created_by_user_id IS NULL OR t.created_by = created_by_user_id)
      AND t.deleted_at IS NULL
    ORDER BY t.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Task statistics function
CREATE OR REPLACE FUNCTION get_task_statistics(
    user_id UUID DEFAULT NULL
)
RETURNS TABLE (
    total_tasks BIGINT,
    pending_tasks BIGINT,
    in_progress_tasks BIGINT,
    completed_tasks BIGINT,
    overdue_tasks BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_tasks,
        COUNT(CASE WHEN t.status = 'pending' THEN 1 END)::BIGINT as pending_tasks,
        COUNT(CASE WHEN t.status = 'in_progress' THEN 1 END)::BIGINT as in_progress_tasks,
        COUNT(CASE WHEN t.status = 'completed' THEN 1 END)::BIGINT as completed_tasks,
        COUNT(CASE WHEN t.status = 'overdue' THEN 1 END)::BIGINT as overdue_tasks
    FROM tasks t
    LEFT JOIN task_assignments ta ON t.id = ta.task_id
    WHERE (user_id IS NULL OR ta.assigned_to = user_id OR t.created_by = user_id)
      AND t.deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Task assignment functions
CREATE OR REPLACE FUNCTION create_scheduled_assignment(
    task_id UUID,
    assigned_to UUID,
    assigned_by UUID,
    scheduled_for TIMESTAMPTZ,
    priority VARCHAR DEFAULT 'medium'
)
RETURNS UUID AS $$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO task_assignments (
        task_id,
        assigned_to,
        assigned_by,
        status,
        priority,
        assigned_at,
        created_at,
        updated_at
    ) VALUES (
        task_id,
        assigned_to,
        assigned_by,
        'pending',
        priority,
        scheduled_for,
        NOW(),
        NOW()
    ) RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Recurring assignment function
CREATE OR REPLACE FUNCTION create_recurring_assignment(
    task_id UUID,
    assigned_to UUID,
    assigned_by UUID,
    recurrence_pattern VARCHAR,
    start_date DATE,
    end_date DATE DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    schedule_id UUID;
BEGIN
    INSERT INTO recurring_assignment_schedules (
        task_id,
        assigned_to,
        assigned_by,
        recurrence_pattern,
        start_date,
        end_date,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        task_id,
        assigned_to,
        assigned_by,
        recurrence_pattern,
        start_date,
        end_date,
        true,
        NOW(),
        NOW()
    ) RETURNING id INTO schedule_id;
    
    RETURN schedule_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Task reassignment function
CREATE OR REPLACE FUNCTION reassign_task(
    assignment_id UUID,
    new_assignee UUID,
    reassigned_by UUID,
    reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE task_assignments 
    SET 
        assigned_to = new_assignee,
        reassigned_by = reassigned_by,
        reassignment_reason = reason,
        updated_at = NOW()
    WHERE id = assignment_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Get assignments with deadlines
CREATE OR REPLACE FUNCTION get_assignments_with_deadlines(
    user_id UUID DEFAULT NULL,
    days_ahead INTEGER DEFAULT 7
)
RETURNS TABLE (
    id UUID,
    task_id UUID,
    task_title VARCHAR,
    assigned_to UUID,
    assignee_name VARCHAR,
    due_date DATE,
    priority VARCHAR,
    status VARCHAR,
    days_until_due INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ta.id,
        t.id as task_id,
        t.title as task_title,
        ta.assigned_to,
        u.username as assignee_name,
        t.due_date,
        ta.priority,
        ta.status,
        (t.due_date - CURRENT_DATE)::INTEGER as days_until_due
    FROM task_assignments ta
    JOIN tasks t ON ta.task_id = t.id
    LEFT JOIN users u ON ta.assigned_to = u.id
    WHERE (user_id IS NULL OR ta.assigned_to = user_id)
      AND t.due_date IS NOT NULL
      AND t.due_date <= CURRENT_DATE + INTERVAL '1 day' * days_ahead
      AND ta.status != 'completed'
      AND t.deleted_at IS NULL
    ORDER BY t.due_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions on all functions
GRANT EXECUTE ON FUNCTION search_tasks(TEXT, TEXT, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_task_statistics(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION create_scheduled_assignment(UUID, UUID, UUID, TIMESTAMPTZ, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION create_recurring_assignment(UUID, UUID, UUID, VARCHAR, DATE, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION reassign_task(UUID, UUID, UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_assignments_with_deadlines(UUID, INTEGER) TO authenticated;

SELECT 'Task management functions created successfully!' as status;