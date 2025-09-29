-- =====================================================
-- Table: tasks
-- Description: Core task management system
-- This table stores the main task definitions with requirements, metadata, and search capabilities
-- =====================================================

-- Create enum types for tasks
CREATE TYPE public.task_status_enum AS ENUM (
    'draft',
    'active',
    'assigned',
    'in_progress',
    'completed',
    'cancelled',
    'on_hold',
    'overdue',
    'pending_review',
    'approved',
    'rejected'
);

CREATE TYPE public.task_priority_enum AS ENUM (
    'low',
    'medium',
    'high',
    'urgent',
    'critical'
);

-- Create tasks table
CREATE TABLE public.tasks (
    -- Primary key with UUID generation
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    
    -- Core task information
    title TEXT NOT NULL,
    description TEXT NULL,
    
    -- Task requirements configuration
    require_task_finished BOOLEAN NULL DEFAULT false,
    require_photo_upload BOOLEAN NULL DEFAULT false,
    require_erp_reference BOOLEAN NULL DEFAULT false,
    
    -- Task workflow configuration
    can_escalate BOOLEAN NULL DEFAULT false,
    can_reassign BOOLEAN NULL DEFAULT false,
    
    -- Creator information
    created_by TEXT NOT NULL,
    created_by_name TEXT NULL,
    created_by_role TEXT NULL,
    
    -- Task status and priority
    status TEXT NULL DEFAULT 'draft'::text,
    priority TEXT NULL DEFAULT 'medium'::text,
    
    -- Audit timestamps
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    deleted_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Due date and time configuration
    due_date DATE NULL,
    due_time TIME WITHOUT TIME ZONE NULL,
    due_datetime TIMESTAMP WITH TIME ZONE NULL,
    
    -- Full-text search vector (auto-generated)
    search_vector TSVECTOR GENERATED ALWAYS AS (
        to_tsvector(
            'english'::regconfig,
            (
                (title || ' '::text) || COALESCE(description, ''::text)
            )
        )
    ) STORED NULL,
    
    -- Primary key constraint
    CONSTRAINT tasks_pkey PRIMARY KEY (id),
    
    -- Check constraint for valid priority values
    CONSTRAINT tasks_priority_check 
        CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'urgent'::text, 'critical'::text])),
    
    -- Check constraint for valid status values
    CONSTRAINT tasks_status_check 
        CHECK (status = ANY (ARRAY[
            'draft'::text, 'active'::text, 'assigned'::text, 'in_progress'::text, 
            'completed'::text, 'cancelled'::text, 'on_hold'::text, 'overdue'::text,
            'pending_review'::text, 'approved'::text, 'rejected'::text
        ])),
    
    -- Check constraint for due date consistency
    CONSTRAINT chk_due_date_consistency 
        CHECK (
            (due_date IS NULL AND due_time IS NULL AND due_datetime IS NULL) OR
            (due_date IS NOT NULL AND due_datetime IS NOT NULL)
        ),
    
    -- Check constraint for logical timestamp order
    CONSTRAINT chk_task_timestamps_logical 
        CHECK (
            (deleted_at IS NULL OR deleted_at >= created_at) AND
            (updated_at >= created_at)
        ),
    
    -- Check constraint for title not empty
    CONSTRAINT chk_title_not_empty 
        CHECK (length(trim(title)) > 0)
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Basic lookup indexes
CREATE INDEX IF NOT EXISTS idx_tasks_created_by 
    ON public.tasks 
    USING btree (created_by) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_status 
    ON public.tasks 
    USING btree (status) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_priority 
    ON public.tasks 
    USING btree (priority) 
    TABLESPACE pg_default;

-- Temporal indexes
CREATE INDEX IF NOT EXISTS idx_tasks_created_at 
    ON public.tasks 
    USING btree (created_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_updated_at 
    ON public.tasks 
    USING btree (updated_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at 
    ON public.tasks 
    USING btree (deleted_at) 
    TABLESPACE pg_default;

-- Due date index (partial for performance)
CREATE INDEX IF NOT EXISTS idx_tasks_due_date 
    ON public.tasks 
    USING btree (due_date) 
    TABLESPACE pg_default
    WHERE (due_date IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_tasks_due_datetime 
    ON public.tasks 
    USING btree (due_datetime) 
    TABLESPACE pg_default
    WHERE (due_datetime IS NOT NULL);

-- Full-text search index
CREATE INDEX IF NOT EXISTS idx_tasks_search_vector 
    ON public.tasks 
    USING gin (search_vector) 
    TABLESPACE pg_default;

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_tasks_status_priority 
    ON public.tasks 
    USING btree (status, priority, created_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_creator_status 
    ON public.tasks 
    USING btree (created_by, status, created_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_active 
    ON public.tasks 
    USING btree (status, priority, due_datetime NULLS LAST) 
    TABLESPACE pg_default
    WHERE deleted_at IS NULL;

-- Requirements-based indexes
CREATE INDEX IF NOT EXISTS idx_tasks_requirements 
    ON public.tasks 
    USING btree (
        require_task_finished, 
        require_photo_upload, 
        require_erp_reference
    ) 
    TABLESPACE pg_default;

-- Workflow capability indexes
CREATE INDEX IF NOT EXISTS idx_tasks_workflow_flags 
    ON public.tasks 
    USING btree (can_escalate, can_reassign) 
    TABLESPACE pg_default;

-- Overdue tasks index
CREATE INDEX IF NOT EXISTS idx_tasks_overdue 
    ON public.tasks 
    USING btree (due_datetime, status) 
    TABLESPACE pg_default
    WHERE due_datetime IS NOT NULL AND deleted_at IS NULL;

-- =====================================================
-- Triggers for Automatic Updates
-- =====================================================

-- Create trigger function for updating updated_at timestamp
CREATE OR REPLACE FUNCTION update_tasks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic timestamp updates
CREATE TRIGGER trigger_update_tasks_updated_at
    BEFORE UPDATE ON public.tasks
    FOR EACH ROW
    EXECUTE FUNCTION update_tasks_updated_at();

-- Create trigger function for due datetime synchronization
CREATE OR REPLACE FUNCTION sync_task_due_datetime()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-calculate due_datetime from due_date and due_time
    IF NEW.due_date IS NOT NULL THEN
        IF NEW.due_time IS NOT NULL THEN
            NEW.due_datetime = NEW.due_date + NEW.due_time;
        ELSE
            NEW.due_datetime = NEW.due_date + TIME '23:59:59';
        END IF;
    ELSE
        NEW.due_datetime = NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for due datetime synchronization
CREATE TRIGGER trigger_sync_task_due_datetime
    BEFORE INSERT OR UPDATE ON public.tasks
    FOR EACH ROW
    EXECUTE FUNCTION sync_task_due_datetime();

-- =====================================================
-- Functions for Task Management
-- =====================================================

-- Function to create a new task
CREATE OR REPLACE FUNCTION create_task(
    p_title TEXT,
    p_description TEXT DEFAULT NULL,
    p_created_by TEXT,
    p_created_by_name TEXT DEFAULT NULL,
    p_created_by_role TEXT DEFAULT NULL,
    p_priority TEXT DEFAULT 'medium',
    p_require_task_finished BOOLEAN DEFAULT false,
    p_require_photo_upload BOOLEAN DEFAULT false,
    p_require_erp_reference BOOLEAN DEFAULT false,
    p_due_date DATE DEFAULT NULL,
    p_due_time TIME DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    task_id UUID;
BEGIN
    INSERT INTO public.tasks (
        title, description, created_by, created_by_name, created_by_role,
        priority, require_task_finished, require_photo_upload, require_erp_reference,
        due_date, due_time, status
    ) VALUES (
        p_title, p_description, p_created_by, p_created_by_name, p_created_by_role,
        p_priority, p_require_task_finished, p_require_photo_upload, p_require_erp_reference,
        p_due_date, p_due_time, 'draft'
    )
    RETURNING id INTO task_id;
    
    RETURN task_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update task status
CREATE OR REPLACE FUNCTION update_task_status(
    p_task_id UUID,
    p_new_status TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.tasks 
    SET status = p_new_status
    WHERE id = p_task_id AND deleted_at IS NULL;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to soft delete task
CREATE OR REPLACE FUNCTION soft_delete_task(p_task_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.tasks 
    SET deleted_at = now(),
        status = 'cancelled'
    WHERE id = p_task_id AND deleted_at IS NULL;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to search tasks
CREATE OR REPLACE FUNCTION search_tasks(
    p_search_query TEXT,
    p_status_filter TEXT DEFAULT NULL,
    p_priority_filter TEXT DEFAULT NULL,
    p_creator_filter TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    task_id UUID,
    title TEXT,
    description TEXT,
    status TEXT,
    priority TEXT,
    created_by TEXT,
    created_by_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    due_datetime TIMESTAMP WITH TIME ZONE,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as task_id,
        t.title,
        t.description,
        t.status,
        t.priority,
        t.created_by,
        t.created_by_name,
        t.created_at,
        t.due_datetime,
        ts_rank(t.search_vector, plainto_tsquery('english', p_search_query)) as rank
    FROM public.tasks t
    WHERE t.deleted_at IS NULL
      AND (p_search_query IS NULL OR t.search_vector @@ plainto_tsquery('english', p_search_query))
      AND (p_status_filter IS NULL OR t.status = p_status_filter)
      AND (p_priority_filter IS NULL OR t.priority = p_priority_filter)
      AND (p_creator_filter IS NULL OR t.created_by = p_creator_filter)
    ORDER BY 
        CASE WHEN p_search_query IS NOT NULL THEN ts_rank(t.search_vector, plainto_tsquery('english', p_search_query)) END DESC,
        t.priority = 'critical' DESC,
        t.priority = 'urgent' DESC,
        t.priority = 'high' DESC,
        t.due_datetime ASC NULLS LAST,
        t.created_at DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to get overdue tasks
CREATE OR REPLACE FUNCTION get_overdue_tasks()
RETURNS TABLE (
    task_id UUID,
    title TEXT,
    description TEXT,
    priority TEXT,
    created_by TEXT,
    due_datetime TIMESTAMP WITH TIME ZONE,
    overdue_hours NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as task_id,
        t.title,
        t.description,
        t.priority,
        t.created_by,
        t.due_datetime,
        EXTRACT(EPOCH FROM (now() - t.due_datetime))/3600 as overdue_hours
    FROM public.tasks t
    WHERE t.deleted_at IS NULL
      AND t.due_datetime IS NOT NULL
      AND t.due_datetime < now()
      AND t.status NOT IN ('completed', 'cancelled', 'approved')
    ORDER BY t.due_datetime ASC;
END;
$$ LANGUAGE plpgsql;

-- Function to get task statistics
CREATE OR REPLACE FUNCTION get_task_statistics(
    p_user_id TEXT DEFAULT NULL,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS TABLE (
    total_tasks INTEGER,
    draft_tasks INTEGER,
    active_tasks INTEGER,
    completed_tasks INTEGER,
    overdue_tasks INTEGER,
    high_priority_tasks INTEGER,
    avg_completion_time INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_tasks,
        COUNT(CASE WHEN t.status = 'draft' THEN 1 END)::INTEGER as draft_tasks,
        COUNT(CASE WHEN t.status IN ('active', 'assigned', 'in_progress') THEN 1 END)::INTEGER as active_tasks,
        COUNT(CASE WHEN t.status = 'completed' THEN 1 END)::INTEGER as completed_tasks,
        COUNT(CASE WHEN t.due_datetime IS NOT NULL AND t.due_datetime < now() AND t.status NOT IN ('completed', 'cancelled') THEN 1 END)::INTEGER as overdue_tasks,
        COUNT(CASE WHEN t.priority IN ('high', 'urgent', 'critical') THEN 1 END)::INTEGER as high_priority_tasks,
        AVG(CASE WHEN t.status = 'completed' THEN t.updated_at - t.created_at END) as avg_completion_time
    FROM public.tasks t
    WHERE t.deleted_at IS NULL
      AND (p_user_id IS NULL OR t.created_by = p_user_id)
      AND (p_start_date IS NULL OR t.created_at >= p_start_date)
      AND (p_end_date IS NULL OR t.created_at <= p_end_date);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Views for Common Task Queries
-- =====================================================

-- View for active tasks with computed fields
CREATE OR REPLACE VIEW active_tasks AS
SELECT 
    t.id,
    t.title,
    t.description,
    t.status,
    t.priority,
    t.created_by,
    t.created_by_name,
    t.created_at,
    t.due_datetime,
    t.require_task_finished,
    t.require_photo_upload,
    t.require_erp_reference,
    t.can_escalate,
    t.can_reassign,
    CASE 
        WHEN t.due_datetime IS NOT NULL AND t.due_datetime < now() THEN true
        ELSE false 
    END as is_overdue,
    CASE 
        WHEN t.due_datetime IS NOT NULL THEN 
            EXTRACT(EPOCH FROM (t.due_datetime - now()))/3600
        ELSE NULL 
    END as hours_until_due,
    CASE 
        WHEN t.priority = 'critical' THEN 5
        WHEN t.priority = 'urgent' THEN 4
        WHEN t.priority = 'high' THEN 3
        WHEN t.priority = 'medium' THEN 2
        WHEN t.priority = 'low' THEN 1
        ELSE 0
    END as priority_score
FROM public.tasks t
WHERE t.deleted_at IS NULL 
  AND t.status NOT IN ('completed', 'cancelled', 'approved')
ORDER BY 
    priority_score DESC,
    due_datetime ASC NULLS LAST,
    created_at DESC;

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.tasks IS 'Core task management system storing task definitions, requirements, metadata, and search capabilities';

COMMENT ON COLUMN public.tasks.id IS 'Primary key - unique identifier for each task';
COMMENT ON COLUMN public.tasks.title IS 'Task title/name (required, non-empty)';
COMMENT ON COLUMN public.tasks.description IS 'Detailed task description (optional)';
COMMENT ON COLUMN public.tasks.require_task_finished IS 'Boolean flag indicating if task completion confirmation is required';
COMMENT ON COLUMN public.tasks.require_photo_upload IS 'Boolean flag indicating if photo evidence is required';
COMMENT ON COLUMN public.tasks.require_erp_reference IS 'Boolean flag indicating if ERP system reference is required';
COMMENT ON COLUMN public.tasks.can_escalate IS 'Boolean flag indicating if task can be escalated';
COMMENT ON COLUMN public.tasks.can_reassign IS 'Boolean flag indicating if task can be reassigned';
COMMENT ON COLUMN public.tasks.created_by IS 'User ID of task creator';
COMMENT ON COLUMN public.tasks.created_by_name IS 'Display name of task creator';
COMMENT ON COLUMN public.tasks.created_by_role IS 'Role of task creator';
COMMENT ON COLUMN public.tasks.status IS 'Current task status (draft, active, assigned, in_progress, completed, etc.)';
COMMENT ON COLUMN public.tasks.priority IS 'Task priority level (low, medium, high, urgent, critical)';
COMMENT ON COLUMN public.tasks.created_at IS 'Timestamp when task was created';
COMMENT ON COLUMN public.tasks.updated_at IS 'Timestamp when task was last updated (auto-updated)';
COMMENT ON COLUMN public.tasks.deleted_at IS 'Soft delete timestamp (NULL = active task)';
COMMENT ON COLUMN public.tasks.due_date IS 'Due date for task completion';
COMMENT ON COLUMN public.tasks.due_time IS 'Due time for task completion';
COMMENT ON COLUMN public.tasks.due_datetime IS 'Combined due date and time (auto-calculated)';
COMMENT ON COLUMN public.tasks.search_vector IS 'Auto-generated full-text search vector for title and description';

-- Function comments
COMMENT ON FUNCTION create_task(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN, BOOLEAN, DATE, TIME) IS 'Creates a new task with comprehensive configuration options';
COMMENT ON FUNCTION update_task_status(UUID, TEXT) IS 'Updates task status with validation for active tasks only';
COMMENT ON FUNCTION search_tasks(TEXT, TEXT, TEXT, TEXT, INTEGER) IS 'Full-text search across tasks with filtering and ranking';
COMMENT ON FUNCTION get_overdue_tasks() IS 'Returns all overdue tasks with overdue duration calculation';
COMMENT ON FUNCTION get_task_statistics(TEXT, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) IS 'Comprehensive task statistics with optional user and date filtering';

-- View comments
COMMENT ON VIEW active_tasks IS 'Enhanced view of active tasks with computed fields for overdue status, urgency scoring, and time calculations';