-- CREATE MISSING FUNCTION: get_tasks_for_receiving_record
-- This function might be missing from the database

CREATE OR REPLACE FUNCTION get_tasks_for_receiving_record(
    receiving_record_id_param UUID
)
RETURNS TABLE(
    task_id UUID,
    title TEXT,
    description TEXT,
    status TEXT,
    priority TEXT,
    created_at TIMESTAMPTZ,
    created_by TEXT,
    created_by_name TEXT,
    require_erp_reference BOOLEAN,
    require_photo_upload BOOLEAN,
    require_task_finished BOOLEAN,
    due_datetime TIMESTAMPTZ
) AS $$
BEGIN
    -- Simple query to get tasks related to receiving record
    RETURN QUERY
    SELECT 
        t.id as task_id,
        t.title,
        t.description,
        t.status,
        t.priority,
        t.created_at,
        t.created_by,
        t.created_by_name,
        t.require_erp_reference,
        t.require_photo_upload,
        t.require_task_finished,
        t.due_datetime
    FROM tasks t
    WHERE t.description LIKE '%' || receiving_record_id_param::TEXT || '%'
       OR t.title LIKE '%receiving%'
       OR t.title LIKE '%delivery%'
    ORDER BY t.created_at DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

-- Alternative: Create a more specific function that looks for recent tasks
CREATE OR REPLACE FUNCTION get_recent_receiving_tasks(
    receiving_record_id_param UUID DEFAULT NULL
)
RETURNS TABLE(
    task_id UUID,
    title TEXT,
    description TEXT,
    status TEXT,
    priority TEXT,
    created_at TIMESTAMPTZ,
    created_by TEXT,
    created_by_name TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as task_id,
        t.title,
        t.description,
        t.status,
        t.priority,
        t.created_at,
        t.created_by,
        t.created_by_name
    FROM tasks t
    WHERE t.created_at >= now() - INTERVAL '1 hour'
       AND (t.title LIKE '%Delivery%' OR t.title LIKE '%delivery%')
    ORDER BY t.created_at DESC;
END;
$$ LANGUAGE plpgsql;