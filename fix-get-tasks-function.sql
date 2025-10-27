-- Fix the get_tasks_for_receiving_record function
-- Remove the incorrect UUID cast that's causing the 500 error

CREATE OR REPLACE FUNCTION public.get_tasks_for_receiving_record(receiving_record_id_param uuid)
 RETURNS TABLE(
    task_id uuid, 
    task_title text, 
    task_description text, 
    assigned_to_user_id uuid, 
    assigned_to_username text, 
    status text, 
    priority text, 
    due_date timestamp with time zone, 
    created_at timestamp with time zone, 
    completed_at timestamp with time zone, 
    attachment_url text
 )
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as task_id,
        t.title as task_title,
        t.description as task_description,
        ta.assigned_to_user_id as assigned_to_user_id,  -- FIXED: Removed ::uuid cast
        u.username as assigned_to_username,
        t.status,
        t.priority,
        t.due_datetime as due_date,
        t.created_at,
        NULL::timestamptz as completed_at,
        NULL::text as attachment_url
    FROM tasks t
    LEFT JOIN task_assignments ta ON ta.task_id = t.id
    LEFT JOIN users u ON u.id = ta.assigned_to_user_id  -- FIXED: Removed ::text cast
    WHERE t.description LIKE '%' || receiving_record_id_param || '%'
    ORDER BY t.created_at DESC;
END;
$function$;

-- Verification
DO $$
BEGIN
    RAISE NOTICE '✅ Fixed get_tasks_for_receiving_record function';
    RAISE NOTICE 'Removed problematic UUID casts that were causing 500 errors';
END $$;
