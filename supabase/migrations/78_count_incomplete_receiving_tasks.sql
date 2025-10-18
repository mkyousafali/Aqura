-- =============================================
-- Function to count incomplete receiving tasks
-- This function counts receiving tasks that are not completed based on task_completions table
-- =============================================

CREATE OR REPLACE FUNCTION count_incomplete_receiving_tasks()
RETURNS INTEGER 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    incomplete_count INTEGER;
BEGIN
    -- Take task_id from receiving_tasks and check if NOT completed in task_completions table
    -- Count as incomplete if there's no matching task_completion OR task_finished_completed = false
    SELECT COUNT(DISTINCT rt.id) INTO incomplete_count
    FROM receiving_tasks rt
    WHERE NOT EXISTS (
        SELECT 1 
        FROM task_completions tc 
        WHERE tc.task_id = rt.task_id 
        AND tc.task_finished_completed = true
    );
    
    RETURN COALESCE(incomplete_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Create an alternative function that uses the tasks table status as well
CREATE OR REPLACE FUNCTION count_incomplete_receiving_tasks_detailed()
RETURNS INTEGER AS $$
DECLARE
    incomplete_count INTEGER;
BEGIN
    -- Count receiving tasks where either:
    -- 1. The receiving task is not marked as completed, OR
    -- 2. The task itself is not completed, OR
    -- 3. There's no task_completion record, OR
    -- 4. The task_completion is not fully finished
    SELECT COUNT(*) INTO incomplete_count
    FROM receiving_tasks rt
    LEFT JOIN tasks t ON rt.task_id = t.id
    LEFT JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
    WHERE (
        rt.task_completed = false 
        OR t.status != 'completed'
        OR tc.id IS NULL
        OR tc.task_finished_completed = false
    );
    
    RETURN COALESCE(incomplete_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to get detailed breakdown of incomplete receiving tasks
CREATE OR REPLACE FUNCTION get_incomplete_receiving_tasks_breakdown()
RETURNS TABLE(
    total_receiving_tasks INTEGER,
    incomplete_receiving_tasks INTEGER,
    missing_task_completions INTEGER,
    incomplete_task_completions INTEGER,
    tasks_not_completed INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH stats AS (
        SELECT 
            COUNT(*) as total_tasks,
            COUNT(CASE WHEN rt.task_completed = false OR t.status != 'completed' THEN 1 END) as incomplete_tasks,
            COUNT(CASE WHEN tc.id IS NULL THEN 1 END) as missing_completions,
            COUNT(CASE WHEN tc.id IS NOT NULL AND tc.task_finished_completed = false THEN 1 END) as incomplete_completions,
            COUNT(CASE WHEN t.status != 'completed' THEN 1 END) as tasks_not_completed
        FROM receiving_tasks rt
        LEFT JOIN tasks t ON rt.task_id = t.id
        LEFT JOIN task_completions tc ON rt.task_id = tc.task_id AND rt.assignment_id = tc.assignment_id
    )
    SELECT 
        s.total_tasks::INTEGER,
        s.incomplete_tasks::INTEGER,
        s.missing_completions::INTEGER,
        s.incomplete_completions::INTEGER,
        s.tasks_not_completed::INTEGER
    FROM stats s;
END;
$$ LANGUAGE plpgsql;

-- Function to count completed receiving tasks
-- This function runs with SECURITY DEFINER to bypass RLS policies
CREATE OR REPLACE FUNCTION count_completed_receiving_tasks()
RETURNS INTEGER 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    completed_count INTEGER;
BEGIN
    -- Simple logic: if task_id from receiving_tasks exists in task_completions table, count as completed
    SELECT COUNT(DISTINCT rt.id) INTO completed_count
    FROM receiving_tasks rt
    WHERE EXISTS (
        SELECT 1 
        FROM task_completions tc 
        WHERE tc.task_id = rt.task_id
    );
    
    RETURN COALESCE(completed_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Alternative function that checks for truly finished tasks
CREATE OR REPLACE FUNCTION count_finished_receiving_tasks()
RETURNS INTEGER AS $$
DECLARE
    finished_count INTEGER;
BEGIN
    -- Count receiving tasks that are marked as task_finished_completed = true
    SELECT COUNT(DISTINCT rt.id) INTO finished_count
    FROM receiving_tasks rt
    WHERE EXISTS (
        SELECT 1 
        FROM task_completions tc 
        WHERE tc.task_id = rt.task_id 
        AND tc.task_finished_completed = true
    );
    
    RETURN COALESCE(finished_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to count receiving records without original bills uploaded
CREATE OR REPLACE FUNCTION count_bills_without_original()
RETURNS INTEGER 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    no_original_count INTEGER;
BEGIN
    -- Count receiving records where original_bill_url is NULL or empty
    SELECT COUNT(*) INTO no_original_count
    FROM receiving_records rr
    WHERE rr.original_bill_url IS NULL 
    OR rr.original_bill_url = ''
    OR TRIM(rr.original_bill_url) = '';
    
    RETURN COALESCE(no_original_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to count receiving records without ERP purchase invoice reference
CREATE OR REPLACE FUNCTION count_bills_without_erp_reference()
RETURNS INTEGER 
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    no_erp_count INTEGER;
BEGIN
    -- Count receiving records where erp_purchase_invoice_reference is NULL or empty
    SELECT COUNT(*) INTO no_erp_count
    FROM receiving_records rr
    WHERE rr.erp_purchase_invoice_reference IS NULL 
    OR rr.erp_purchase_invoice_reference = ''
    OR TRIM(rr.erp_purchase_invoice_reference) = '';
    
    RETURN COALESCE(no_erp_count, 0);
END;
$$ LANGUAGE plpgsql;

-- Debug function to check data in tables
CREATE OR REPLACE FUNCTION debug_receiving_tasks_data()
RETURNS TABLE(
    total_receiving_tasks INTEGER,
    total_task_completions INTEGER,
    receiving_task_ids TEXT,
    task_completion_task_ids TEXT,
    matching_completed_tasks INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM receiving_tasks) as total_receiving_tasks,
        (SELECT COUNT(*)::INTEGER FROM task_completions) as total_task_completions,
        (SELECT string_agg(rt.task_id::TEXT, ', ') FROM receiving_tasks rt LIMIT 10) as receiving_task_ids,
        (SELECT string_agg(tc.task_id::TEXT, ', ') FROM task_completions tc WHERE tc.task_finished_completed = true LIMIT 10) as task_completion_task_ids,
        (SELECT COUNT(DISTINCT rt.id)::INTEGER 
         FROM receiving_tasks rt 
         WHERE EXISTS (
             SELECT 1 FROM task_completions tc 
             WHERE tc.task_id = rt.task_id 
             AND tc.task_finished_completed = true
         )) as matching_completed_tasks;
END;
$$ LANGUAGE plpgsql;

-- Drop existing functions with incorrect return types
DROP FUNCTION IF EXISTS get_all_receiving_tasks();
DROP FUNCTION IF EXISTS get_incomplete_receiving_tasks();
DROP FUNCTION IF EXISTS get_completed_receiving_tasks();

-- Function to get all receiving tasks data for display
CREATE OR REPLACE FUNCTION get_all_receiving_tasks()
RETURNS TABLE(
    id UUID,
    receiving_record_id UUID,
    task_id UUID,
    role_type VARCHAR,
    assignment_id UUID,
    task_completed BOOLEAN,
    completed_at TIMESTAMPTZ,
    erp_reference_number VARCHAR,
    created_at TIMESTAMPTZ,
    task_title TEXT,
    task_status TEXT,
    task_created_at TIMESTAMPTZ,
    assigned_user_name VARCHAR,
    completion_status VARCHAR
) 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rt.id,
        rt.receiving_record_id,
        rt.task_id,
        rt.role_type,
        rt.assignment_id,
        rt.task_completed,
        rt.completed_at,
        rt.erp_reference_number,
        rt.created_at,
        t.title as task_title,
        t.status as task_status,
        t.created_at as task_created_at,
        COALESCE(he.name, u.username, 'Unassigned') as assigned_user_name,
        CASE 
            WHEN EXISTS (
                SELECT 1 FROM task_completions tc 
                WHERE tc.task_id = rt.task_id 
                AND tc.task_finished_completed = true
            ) THEN 'Completed'::VARCHAR
            ELSE 'Pending'::VARCHAR
        END as completion_status
    FROM receiving_tasks rt
    LEFT JOIN tasks t ON rt.task_id = t.id
    LEFT JOIN users u ON rt.assigned_user_id = u.id
    LEFT JOIN hr_employees he ON u.employee_id = he.id
    ORDER BY rt.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get incomplete receiving tasks data for display
CREATE OR REPLACE FUNCTION get_incomplete_receiving_tasks()
RETURNS TABLE(
    id UUID,
    receiving_record_id UUID,
    task_id UUID,
    role_type VARCHAR,
    assignment_id UUID,
    task_completed BOOLEAN,
    completed_at TIMESTAMPTZ,
    erp_reference_number VARCHAR,
    created_at TIMESTAMPTZ,
    task_title TEXT,
    task_status TEXT,
    task_created_at TIMESTAMPTZ,
    days_pending INTEGER,
    assigned_user_name VARCHAR,
    completion_status VARCHAR
) 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rt.id,
        rt.receiving_record_id,
        rt.task_id,
        rt.role_type,
        rt.assignment_id,
        rt.task_completed,
        rt.completed_at,
        rt.erp_reference_number,
        rt.created_at,
        t.title as task_title,
        t.status as task_status,
        t.created_at as task_created_at,
        EXTRACT(DAY FROM (NOW() - rt.created_at))::INTEGER as days_pending,
        COALESCE(he.name, u.username, 'Unassigned') as assigned_user_name,
        'Incomplete'::VARCHAR as completion_status
    FROM receiving_tasks rt
    LEFT JOIN tasks t ON rt.task_id = t.id
    LEFT JOIN users u ON rt.assigned_user_id = u.id
    LEFT JOIN hr_employees he ON u.employee_id = he.id
    WHERE NOT EXISTS (
        SELECT 1 
        FROM task_completions tc 
        WHERE tc.task_id = rt.task_id 
        AND tc.task_finished_completed = true
    )
    ORDER BY rt.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get completed receiving tasks data for display
CREATE OR REPLACE FUNCTION get_completed_receiving_tasks()
RETURNS TABLE(
    id UUID,
    task_id UUID,
    assignment_id UUID,
    completed_by TEXT,
    completed_by_name TEXT,
    completed_at TIMESTAMPTZ,
    task_finished_completed BOOLEAN,
    erp_reference_number TEXT,
    task_title TEXT,
    task_status TEXT,
    task_created_at TIMESTAMPTZ
) 
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tc.id,
        tc.task_id,
        tc.assignment_id,
        tc.completed_by,
        tc.completed_by_name,
        tc.completed_at,
        tc.task_finished_completed,
        tc.erp_reference_number,
        t.title as task_title,
        t.status as task_status,
        t.created_at as task_created_at
    FROM task_completions tc
    INNER JOIN receiving_tasks rt ON tc.task_id = rt.task_id
    LEFT JOIN tasks t ON tc.task_id = t.id
    WHERE tc.task_finished_completed = true
    ORDER BY tc.completed_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Test the functions with actual data
DO $$
DECLARE
    rt_count INTEGER;
    tc_count INTEGER;
    completed_count INTEGER;
BEGIN
    -- Check receiving_tasks count
    SELECT COUNT(*) INTO rt_count FROM receiving_tasks;
    RAISE NOTICE 'Total receiving_tasks: %', rt_count;
    
    -- Check task_completions count
    SELECT COUNT(*) INTO tc_count FROM task_completions;
    RAISE NOTICE 'Total task_completions: %', tc_count;
    
    -- Test the function directly
    SELECT count_completed_receiving_tasks() INTO completed_count;
    RAISE NOTICE 'Completed receiving tasks: %', completed_count;
    
    -- Test manual query
    SELECT COUNT(DISTINCT rt.id) INTO completed_count
    FROM receiving_tasks rt
    WHERE EXISTS (
        SELECT 1 
        FROM task_completions tc 
        WHERE tc.task_id = rt.task_id
    );
    RAISE NOTICE 'Manual query result: %', completed_count;
    
    RAISE NOTICE 'Receiving tasks count functions created successfully!';
    RAISE NOTICE 'Use count_incomplete_receiving_tasks() to get incomplete count';
    RAISE NOTICE 'Use count_completed_receiving_tasks() to get completed count for dashboard';
    RAISE NOTICE 'Use count_bills_without_original() to get bills without original uploads';
    RAISE NOTICE 'Use count_bills_without_erp_reference() to get bills without ERP references';
    RAISE NOTICE 'Use get_incomplete_receiving_tasks_breakdown() for detailed analysis';
    RAISE NOTICE 'Use debug_receiving_tasks_data() to debug data issues';
    RAISE NOTICE 'Use get_all_receiving_tasks() to get all receiving tasks data';
    RAISE NOTICE 'Use get_incomplete_receiving_tasks() to get incomplete tasks data';
    RAISE NOTICE 'Use get_completed_receiving_tasks() to get completed tasks data';
END $$;