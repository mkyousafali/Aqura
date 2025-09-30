-- =====================================================
-- Task Assignment Schema Update
-- Description: Enhancements for task assignment management
-- This script provides optimizations for the existing task assignment system
-- Run this after the base task and assignment schemas are in place
-- =====================================================

-- First, let's add some indexes that might be missing for better performance
CREATE INDEX IF NOT EXISTS idx_task_assignments_task_status_composite 
    ON public.task_assignments 
    USING btree (task_id, status, assigned_at DESC) 
    TABLESPACE pg_default;

-- Add index for assignment lookups by multiple criteria
CREATE INDEX IF NOT EXISTS idx_task_assignments_comprehensive 
    ON public.task_assignments 
    USING btree (
        assigned_to_user_id, 
        assigned_to_branch_id, 
        assignment_type, 
        status, 
        assigned_at DESC
    ) 
    TABLESPACE pg_default;

-- =====================================================
-- Enhanced Functions for Task Assignment Management
-- =====================================================

-- Function to assign task to multiple users at once
CREATE OR REPLACE FUNCTION assign_task_to_multiple_users(
    p_task_id UUID,
    p_user_ids TEXT[],
    p_assigned_by TEXT,
    p_assigned_by_name TEXT DEFAULT NULL
)
RETURNS UUID[] AS $$
DECLARE
    assignment_ids UUID[] := '{}';
    user_id TEXT;
    assignment_id UUID;
BEGIN
    FOREACH user_id IN ARRAY p_user_ids
    LOOP
        INSERT INTO public.task_assignments (
            task_id, assignment_type, assigned_to_user_id, assigned_by, assigned_by_name
        ) VALUES (
            p_task_id, 'individual', user_id, p_assigned_by, p_assigned_by_name
        )
        ON CONFLICT (task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id) 
        DO UPDATE SET
            assigned_by = EXCLUDED.assigned_by,
            assigned_by_name = EXCLUDED.assigned_by_name,
            assigned_at = now(),
            status = 'assigned'
        RETURNING id INTO assignment_id;
        
        assignment_ids := array_append(assignment_ids, assignment_id);
    END LOOP;
    
    RETURN assignment_ids;
END;
$$ LANGUAGE plpgsql;

-- Function to get detailed assignment information with task and user details
CREATE OR REPLACE FUNCTION get_assignment_details(
    p_assignment_id UUID DEFAULT NULL,
    p_task_id UUID DEFAULT NULL,
    p_user_id TEXT DEFAULT NULL,
    p_branch_id UUID DEFAULT NULL
)
RETURNS TABLE (
    assignment_id UUID,
    task_id UUID,
    task_title TEXT,
    task_description TEXT,
    task_priority TEXT,
    task_status TEXT,
    task_due_datetime TIMESTAMP WITH TIME ZONE,
    assignment_type TEXT,
    assignment_status TEXT,
    assigned_to_user_id TEXT,
    assigned_to_branch_id UUID,
    assigned_by TEXT,
    assigned_by_name TEXT,
    assigned_at TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    is_overdue BOOLEAN,
    hours_until_due NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ta.id as assignment_id,
        t.id as task_id,
        t.title as task_title,
        t.description as task_description,
        t.priority as task_priority,
        t.status as task_status,
        t.due_datetime as task_due_datetime,
        ta.assignment_type,
        ta.status as assignment_status,
        ta.assigned_to_user_id,
        ta.assigned_to_branch_id,
        ta.assigned_by,
        ta.assigned_by_name,
        ta.assigned_at,
        ta.started_at,
        ta.completed_at,
        CASE 
            WHEN t.due_datetime IS NOT NULL AND t.due_datetime < now() THEN true
            ELSE false 
        END as is_overdue,
        CASE 
            WHEN t.due_datetime IS NOT NULL THEN 
                EXTRACT(EPOCH FROM (t.due_datetime - now()))/3600
            ELSE NULL 
        END as hours_until_due
    FROM public.task_assignments ta
    JOIN public.tasks t ON ta.task_id = t.id
    WHERE (p_assignment_id IS NULL OR ta.id = p_assignment_id)
      AND (p_task_id IS NULL OR ta.task_id = p_task_id)
      AND (p_user_id IS NULL OR ta.assigned_to_user_id = p_user_id)
      AND (p_branch_id IS NULL OR ta.assigned_to_branch_id = p_branch_id)
      AND t.deleted_at IS NULL
    ORDER BY ta.assigned_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to bulk update assignment statuses
CREATE OR REPLACE FUNCTION bulk_update_assignment_status(
    p_assignment_ids UUID[],
    p_new_status TEXT
)
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE public.task_assignments 
    SET status = p_new_status
    WHERE id = ANY(p_assignment_ids);
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- Function to cancel all assignments for a task
CREATE OR REPLACE FUNCTION cancel_task_assignments(
    p_task_id UUID,
    p_cancelled_by TEXT DEFAULT 'system'
)
RETURNS INTEGER AS $$
DECLARE
    cancelled_count INTEGER;
BEGIN
    UPDATE public.task_assignments 
    SET status = 'cancelled',
        assigned_by = p_cancelled_by,
        assigned_at = now()
    WHERE task_id = p_task_id 
      AND status NOT IN ('completed', 'cancelled');
    
    GET DIAGNOSTICS cancelled_count = ROW_COUNT;
    RETURN cancelled_count;
END;
$$ LANGUAGE plpgsql;

-- Function to get assignment statistics for dashboard
CREATE OR REPLACE FUNCTION get_assignment_statistics(
    p_user_id TEXT DEFAULT NULL,
    p_branch_id UUID DEFAULT NULL,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS TABLE (
    total_assignments INTEGER,
    assigned_count INTEGER,
    in_progress_count INTEGER,
    completed_count INTEGER,
    overdue_count INTEGER,
    acceptance_rate NUMERIC,
    avg_completion_time INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_assignments,
        COUNT(CASE WHEN ta.status = 'assigned' THEN 1 END)::INTEGER as assigned_count,
        COUNT(CASE WHEN ta.status = 'in_progress' THEN 1 END)::INTEGER as in_progress_count,
        COUNT(CASE WHEN ta.status = 'completed' THEN 1 END)::INTEGER as completed_count,
        COUNT(CASE WHEN t.due_datetime IS NOT NULL AND t.due_datetime < now() AND ta.status NOT IN ('completed', 'cancelled') THEN 1 END)::INTEGER as overdue_count,
        CASE 
            WHEN COUNT(CASE WHEN ta.status != 'rejected' THEN 1 END) > 0 THEN
                (COUNT(CASE WHEN ta.status IN ('accepted', 'in_progress', 'completed') THEN 1 END)::NUMERIC / 
                 COUNT(CASE WHEN ta.status != 'rejected' THEN 1 END)::NUMERIC * 100)
            ELSE 0 
        END as acceptance_rate,
        AVG(CASE WHEN ta.status = 'completed' AND ta.started_at IS NOT NULL THEN ta.completed_at - ta.started_at END) as avg_completion_time
    FROM public.task_assignments ta
    JOIN public.tasks t ON ta.task_id = t.id
    WHERE (p_user_id IS NULL OR ta.assigned_to_user_id = p_user_id)
      AND (p_branch_id IS NULL OR ta.assigned_to_branch_id = p_branch_id)
      AND (p_start_date IS NULL OR ta.assigned_at >= p_start_date)
      AND (p_end_date IS NULL OR ta.assigned_at <= p_end_date)
      AND t.deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Enhanced Views for Assignment Management
-- =====================================================

-- View for assignment dashboard with comprehensive details
CREATE OR REPLACE VIEW assignment_dashboard AS
SELECT 
    ta.id as assignment_id,
    ta.task_id,
    t.title as task_title,
    t.description as task_description,
    t.priority as task_priority,
    t.status as task_status,
    ta.assignment_type,
    ta.assigned_to_user_id,
    ta.assigned_to_branch_id,
    b.name_en as branch_name,
    ta.assigned_by,
    ta.assigned_by_name,
    ta.status as assignment_status,
    ta.assigned_at,
    ta.started_at,
    ta.completed_at,
    t.due_datetime,
    t.require_task_finished,
    t.require_photo_upload,
    t.require_erp_reference,
    -- Computed fields
    CASE 
        WHEN t.due_datetime IS NOT NULL AND t.due_datetime < now() AND ta.status NOT IN ('completed', 'cancelled') THEN true
        ELSE false 
    END as is_overdue,
    CASE 
        WHEN t.due_datetime IS NOT NULL THEN 
            EXTRACT(EPOCH FROM (t.due_datetime - now()))/3600
        ELSE NULL 
    END as hours_until_due,
    CASE 
        WHEN ta.started_at IS NOT NULL AND ta.completed_at IS NOT NULL THEN
            EXTRACT(EPOCH FROM (ta.completed_at - ta.started_at))/3600
        ELSE NULL
    END as completion_hours,
    CASE 
        WHEN t.priority = 'critical' THEN 5
        WHEN t.priority = 'urgent' THEN 4
        WHEN t.priority = 'high' THEN 3
        WHEN t.priority = 'medium' THEN 2
        WHEN t.priority = 'low' THEN 1
        ELSE 0
    END as priority_score
FROM public.task_assignments ta
JOIN public.tasks t ON ta.task_id = t.id
LEFT JOIN public.branches b ON ta.assigned_to_branch_id = b.id
WHERE t.deleted_at IS NULL
ORDER BY 
    priority_score DESC,
    is_overdue DESC,
    hours_until_due ASC NULLS LAST,
    ta.assigned_at DESC;

-- View for user workload analysis
CREATE OR REPLACE VIEW user_workload_summary AS
SELECT 
    ta.assigned_to_user_id as user_id,
    COUNT(*) as total_assignments,
    COUNT(CASE WHEN ta.status = 'assigned' THEN 1 END) as pending_count,
    COUNT(CASE WHEN ta.status = 'in_progress' THEN 1 END) as active_count,
    COUNT(CASE WHEN ta.status = 'completed' THEN 1 END) as completed_count,
    COUNT(CASE WHEN t.due_datetime IS NOT NULL AND t.due_datetime < now() AND ta.status NOT IN ('completed', 'cancelled') THEN 1 END) as overdue_count,
    COUNT(CASE WHEN t.priority IN ('high', 'urgent', 'critical') THEN 1 END) as high_priority_count,
    AVG(CASE 
        WHEN ta.status = 'completed' AND ta.started_at IS NOT NULL AND ta.completed_at IS NOT NULL THEN
            EXTRACT(EPOCH FROM (ta.completed_at - ta.started_at))/3600
        ELSE NULL
    END) as avg_completion_hours,
    MAX(ta.assigned_at) as last_assignment_date
FROM public.task_assignments ta
JOIN public.tasks t ON ta.task_id = t.id
WHERE ta.assigned_to_user_id IS NOT NULL
  AND t.deleted_at IS NULL
GROUP BY ta.assigned_to_user_id
ORDER BY total_assignments DESC;

-- =====================================================
-- Triggers for Assignment Notifications
-- =====================================================

-- Create trigger function for assignment notifications
CREATE OR REPLACE FUNCTION notify_assignment_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- Notify on new assignments
    IF TG_OP = 'INSERT' THEN
        PERFORM pg_notify(
            'task_assignment_created',
            json_build_object(
                'assignment_id', NEW.id,
                'task_id', NEW.task_id,
                'assigned_to_user_id', NEW.assigned_to_user_id,
                'assigned_to_branch_id', NEW.assigned_to_branch_id,
                'assigned_by', NEW.assigned_by
            )::text
        );
        RETURN NEW;
    END IF;
    
    -- Notify on status changes
    IF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
        PERFORM pg_notify(
            'task_assignment_status_changed',
            json_build_object(
                'assignment_id', NEW.id,
                'task_id', NEW.task_id,
                'old_status', OLD.status,
                'new_status', NEW.status,
                'assigned_to_user_id', NEW.assigned_to_user_id
            )::text
        );
        RETURN NEW;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for assignment notifications
CREATE TRIGGER trigger_assignment_notifications
    AFTER INSERT OR UPDATE ON public.task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION notify_assignment_changes();

-- =====================================================
-- Security Enhancements
-- =====================================================

-- Create RLS policies for task assignments (if RLS is enabled)
-- Note: Uncomment these if you're using Row Level Security

/*
-- Enable RLS on task_assignments
ALTER TABLE public.task_assignments ENABLE ROW LEVEL SECURITY;

-- Policy: Users can see their own assignments
CREATE POLICY "Users can view their own assignments" ON public.task_assignments
    FOR SELECT USING (
        assigned_to_user_id = current_setting('app.current_user_id', true)
        OR assigned_by = current_setting('app.current_user_id', true)
    );

-- Policy: Users can update status of their own assignments
CREATE POLICY "Users can update their own assignment status" ON public.task_assignments
    FOR UPDATE USING (
        assigned_to_user_id = current_setting('app.current_user_id', true)
    );

-- Policy: Admins can manage all assignments
CREATE POLICY "Admins can manage all assignments" ON public.task_assignments
    FOR ALL USING (
        current_setting('app.current_user_role', true) IN ('Master Admin', 'Admin')
    );
*/

-- =====================================================
-- Table Comments and Documentation Updates
-- =====================================================

COMMENT ON FUNCTION assign_task_to_multiple_users(UUID, TEXT[], TEXT, TEXT) IS 'Assigns a single task to multiple users simultaneously with bulk processing';
COMMENT ON FUNCTION get_assignment_details(UUID, UUID, TEXT, UUID) IS 'Retrieves comprehensive assignment details with task information and computed fields';
COMMENT ON FUNCTION bulk_update_assignment_status(UUID[], TEXT) IS 'Updates status for multiple assignments in a single operation';
COMMENT ON FUNCTION cancel_task_assignments(UUID, TEXT) IS 'Cancels all active assignments for a specific task';
COMMENT ON FUNCTION get_assignment_statistics(TEXT, UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) IS 'Provides comprehensive assignment statistics for dashboard and reporting';

COMMENT ON VIEW assignment_dashboard IS 'Comprehensive assignment view with computed fields for dashboard display';
COMMENT ON VIEW user_workload_summary IS 'User workload analysis view for capacity planning and performance tracking';

-- =====================================================
-- Performance Monitoring Queries
-- =====================================================

-- Query to identify slow assignment operations
/*
-- Use this query to monitor assignment performance:

SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation,
    most_common_vals,
    most_common_freqs
FROM pg_stats 
WHERE tablename = 'task_assignments' 
ORDER BY n_distinct DESC;

-- Query to check index usage:
SELECT 
    indexrelname as index_name,
    idx_tup_read,
    idx_tup_fetch,
    idx_scan
FROM pg_stat_user_indexes 
WHERE schemaname = 'public' 
  AND relname = 'task_assignments'
ORDER BY idx_scan DESC;
*/

-- =====================================================
-- Cleanup and Maintenance
-- =====================================================

-- Function to cleanup old completed assignments (optional)
CREATE OR REPLACE FUNCTION cleanup_old_assignments(
    p_days_old INTEGER DEFAULT 365
)
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- This is a soft cleanup - just marks old completed assignments
    -- Uncomment the DELETE statement if you want hard deletion
    
    /*
    DELETE FROM public.task_assignments 
    WHERE status IN ('completed', 'cancelled', 'rejected')
      AND completed_at < (now() - INTERVAL '1 day' * p_days_old);
    */
    
    -- For now, just return count of what would be deleted
    SELECT COUNT(*) INTO deleted_count
    FROM public.task_assignments 
    WHERE status IN ('completed', 'cancelled', 'rejected')
      AND completed_at < (now() - INTERVAL '1 day' * p_days_old);
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_assignments(INTEGER) IS 'Identifies old completed assignments for cleanup (modify function to enable actual deletion)';

-- =====================================================
-- End of Task Assignment Schema Update
-- =====================================================

-- Log completion
SELECT 'Task Assignment Schema Update completed successfully!' as result;