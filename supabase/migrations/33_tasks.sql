-- Create tasks table for managing task definitions and metadata
-- This table is the core table for task management with full-text search capabilities

-- Create the tasks table
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT NULL,
    require_task_finished BOOLEAN NULL DEFAULT false,
    require_photo_upload BOOLEAN NULL DEFAULT false,
    require_erp_reference BOOLEAN NULL DEFAULT false,
    can_escalate BOOLEAN NULL DEFAULT false,
    can_reassign BOOLEAN NULL DEFAULT false,
    created_by TEXT NOT NULL,
    created_by_name TEXT NULL,
    created_by_role TEXT NULL,
    status TEXT NULL DEFAULT 'draft'::text,
    priority TEXT NULL DEFAULT 'medium'::text,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    deleted_at TIMESTAMP WITH TIME ZONE NULL,
    due_date DATE NULL,
    due_time TIME WITHOUT TIME ZONE NULL,
    due_datetime TIMESTAMP WITH TIME ZONE NULL,
    search_vector TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('english'::regconfig, (title || ' '::text) || COALESCE(description, ''::text))
    ) STORED NULL,
    
    CONSTRAINT tasks_pkey PRIMARY KEY (id),
    CONSTRAINT tasks_priority_check 
        CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text]))
) TABLESPACE pg_default;

-- Create indexes for efficient queries (original indexes)
CREATE INDEX IF NOT EXISTS idx_tasks_created_by 
ON public.tasks USING btree (created_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_status 
ON public.tasks USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_created_at 
ON public.tasks USING btree (created_at DESC) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at 
ON public.tasks USING btree (deleted_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_search_vector 
ON public.tasks USING gin (search_vector) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_tasks_due_date 
ON public.tasks USING btree (due_date) 
TABLESPACE pg_default
WHERE due_date IS NOT NULL;

-- Create original trigger
CREATE TRIGGER cleanup_task_notifications_trigger
AFTER DELETE ON tasks 
FOR EACH ROW 
EXECUTE FUNCTION trigger_cleanup_task_notifications();

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_tasks_priority 
ON public.tasks (priority);

CREATE INDEX IF NOT EXISTS idx_tasks_updated_at 
ON public.tasks (updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_tasks_due_datetime 
ON public.tasks (due_datetime) 
WHERE due_datetime IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_created_by_role 
ON public.tasks (created_by_role);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_tasks_status_priority 
ON public.tasks (status, priority);

CREATE INDEX IF NOT EXISTS idx_tasks_created_by_status 
ON public.tasks (created_by, status);

CREATE INDEX IF NOT EXISTS idx_tasks_status_created_at 
ON public.tasks (status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_tasks_priority_due_date 
ON public.tasks (priority, due_date) 
WHERE due_date IS NOT NULL;

-- Create partial indexes for performance
CREATE INDEX IF NOT EXISTS idx_tasks_active 
ON public.tasks (created_at DESC) 
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_deleted 
ON public.tasks (deleted_at DESC) 
WHERE deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_with_requirements 
ON public.tasks (created_at DESC) 
WHERE require_task_finished = true OR require_photo_upload = true OR require_erp_reference = true;

CREATE INDEX IF NOT EXISTS idx_tasks_escalatable 
ON public.tasks (status, priority) 
WHERE can_escalate = true;

CREATE INDEX IF NOT EXISTS idx_tasks_reassignable 
ON public.tasks (status) 
WHERE can_reassign = true;

CREATE INDEX IF NOT EXISTS idx_tasks_overdue 
ON public.tasks (due_datetime) 
WHERE due_datetime < now() AND status NOT IN ('completed', 'cancelled');

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_tasks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_tasks_updated_at 
BEFORE UPDATE ON tasks 
FOR EACH ROW 
EXECUTE FUNCTION update_tasks_updated_at();

-- Add additional validation constraints
ALTER TABLE public.tasks 
ADD CONSTRAINT chk_title_not_empty 
CHECK (TRIM(title) != '');

ALTER TABLE public.tasks 
ADD CONSTRAINT chk_status_valid 
CHECK (status IN (
    'draft', 'active', 'pending', 'in_progress', 'review', 'completed', 'cancelled', 'on_hold'
));

ALTER TABLE public.tasks 
ADD CONSTRAINT chk_due_datetime_consistency 
CHECK ((due_date IS NULL AND due_time IS NULL) OR (due_date IS NOT NULL));

ALTER TABLE public.tasks 
ADD CONSTRAINT chk_deleted_at_after_created 
CHECK (deleted_at IS NULL OR deleted_at >= created_at);

-- Extend priority constraint to include more levels
ALTER TABLE public.tasks 
DROP CONSTRAINT IF EXISTS tasks_priority_check;

ALTER TABLE public.tasks 
ADD CONSTRAINT chk_priority_valid 
CHECK (priority IN ('low', 'medium', 'high', 'urgent', 'critical'));

-- Add additional columns for enhanced functionality
ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS category VARCHAR(100);

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS tags TEXT[];

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS estimated_duration INTERVAL;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS actual_duration INTERVAL;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS department_id BIGINT;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS branch_id BIGINT;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS project_id UUID;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS template_id UUID;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS parent_task_id UUID;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS completion_percentage INTEGER DEFAULT 0;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS approval_required BOOLEAN DEFAULT false;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS approved_by TEXT;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS external_reference VARCHAR(255);

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS is_template BOOLEAN DEFAULT false;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT false;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS recurrence_pattern JSONB;

ALTER TABLE public.tasks 
ADD COLUMN IF NOT EXISTS auto_assign_rules JSONB DEFAULT '{}';

-- Add foreign keys for new columns
ALTER TABLE public.tasks 
ADD CONSTRAINT tasks_parent_task_id_fkey 
FOREIGN KEY (parent_task_id) REFERENCES tasks (id) ON DELETE CASCADE;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_departments') THEN
        ALTER TABLE public.tasks 
        ADD CONSTRAINT tasks_department_id_fkey 
        FOREIGN KEY (department_id) REFERENCES hr_departments (id) ON DELETE SET NULL;
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'branches') THEN
        ALTER TABLE public.tasks 
        ADD CONSTRAINT tasks_branch_id_fkey 
        FOREIGN KEY (branch_id) REFERENCES branches (id) ON DELETE SET NULL;
    END IF;
END $$;

-- Add validation for new columns
ALTER TABLE public.tasks 
ADD CONSTRAINT chk_completion_percentage_valid 
CHECK (completion_percentage >= 0 AND completion_percentage <= 100);

ALTER TABLE public.tasks 
ADD CONSTRAINT chk_approval_sequence 
CHECK (approved_at IS NULL OR approved_at >= created_at);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_tasks_category 
ON public.tasks (category);

CREATE INDEX IF NOT EXISTS idx_tasks_department 
ON public.tasks (department_id);

CREATE INDEX IF NOT EXISTS idx_tasks_branch 
ON public.tasks (branch_id);

CREATE INDEX IF NOT EXISTS idx_tasks_project 
ON public.tasks (project_id);

CREATE INDEX IF NOT EXISTS idx_tasks_template 
ON public.tasks (template_id);

CREATE INDEX IF NOT EXISTS idx_tasks_parent_task 
ON public.tasks (parent_task_id);

CREATE INDEX IF NOT EXISTS idx_tasks_completion_percentage 
ON public.tasks (completion_percentage);

CREATE INDEX IF NOT EXISTS idx_tasks_approval_required 
ON public.tasks (approval_required) 
WHERE approval_required = true;

CREATE INDEX IF NOT EXISTS idx_tasks_approved_by 
ON public.tasks (approved_by);

CREATE INDEX IF NOT EXISTS idx_tasks_external_reference 
ON public.tasks (external_reference);

CREATE INDEX IF NOT EXISTS idx_tasks_is_template 
ON public.tasks (is_template) 
WHERE is_template = true;

CREATE INDEX IF NOT EXISTS idx_tasks_is_recurring 
ON public.tasks (is_recurring) 
WHERE is_recurring = true;

-- Create GIN indexes for arrays and JSONB
CREATE INDEX IF NOT EXISTS idx_tasks_tags 
ON public.tasks USING gin (tags);

CREATE INDEX IF NOT EXISTS idx_tasks_metadata 
ON public.tasks USING gin (metadata);

CREATE INDEX IF NOT EXISTS idx_tasks_recurrence_pattern 
ON public.tasks USING gin (recurrence_pattern);

CREATE INDEX IF NOT EXISTS idx_tasks_auto_assign_rules 
ON public.tasks USING gin (auto_assign_rules);

-- Add table and column comments
COMMENT ON TABLE public.tasks IS 'Core task definitions with comprehensive metadata and search capabilities';
COMMENT ON COLUMN public.tasks.id IS 'Unique identifier for the task';
COMMENT ON COLUMN public.tasks.title IS 'Task title/name';
COMMENT ON COLUMN public.tasks.description IS 'Detailed task description';
COMMENT ON COLUMN public.tasks.require_task_finished IS 'Whether task completion confirmation is required';
COMMENT ON COLUMN public.tasks.require_photo_upload IS 'Whether photo upload is required for completion';
COMMENT ON COLUMN public.tasks.require_erp_reference IS 'Whether ERP reference is required';
COMMENT ON COLUMN public.tasks.can_escalate IS 'Whether task can be escalated';
COMMENT ON COLUMN public.tasks.can_reassign IS 'Whether task can be reassigned';
COMMENT ON COLUMN public.tasks.created_by IS 'User who created the task';
COMMENT ON COLUMN public.tasks.created_by_name IS 'Name of the user who created the task';
COMMENT ON COLUMN public.tasks.created_by_role IS 'Role of the user who created the task';
COMMENT ON COLUMN public.tasks.status IS 'Current task status';
COMMENT ON COLUMN public.tasks.priority IS 'Task priority level';
COMMENT ON COLUMN public.tasks.due_date IS 'Due date for the task';
COMMENT ON COLUMN public.tasks.due_time IS 'Due time for the task';
COMMENT ON COLUMN public.tasks.due_datetime IS 'Combined due datetime';
COMMENT ON COLUMN public.tasks.search_vector IS 'Full-text search vector';
COMMENT ON COLUMN public.tasks.category IS 'Task category/type';
COMMENT ON COLUMN public.tasks.tags IS 'Array of tags for categorization';
COMMENT ON COLUMN public.tasks.estimated_duration IS 'Estimated time to complete';
COMMENT ON COLUMN public.tasks.actual_duration IS 'Actual time taken to complete';
COMMENT ON COLUMN public.tasks.department_id IS 'Department responsible for the task';
COMMENT ON COLUMN public.tasks.branch_id IS 'Branch responsible for the task';
COMMENT ON COLUMN public.tasks.project_id IS 'Project this task belongs to';
COMMENT ON COLUMN public.tasks.template_id IS 'Template this task was created from';
COMMENT ON COLUMN public.tasks.parent_task_id IS 'Parent task for subtasks';
COMMENT ON COLUMN public.tasks.completion_percentage IS 'Task completion percentage (0-100)';
COMMENT ON COLUMN public.tasks.approval_required IS 'Whether task requires approval';
COMMENT ON COLUMN public.tasks.approved_by IS 'User who approved the task';
COMMENT ON COLUMN public.tasks.approved_at IS 'When the task was approved';
COMMENT ON COLUMN public.tasks.rejection_reason IS 'Reason for rejection if applicable';
COMMENT ON COLUMN public.tasks.external_reference IS 'External system reference';
COMMENT ON COLUMN public.tasks.metadata IS 'Additional metadata as JSON';
COMMENT ON COLUMN public.tasks.is_template IS 'Whether this is a task template';
COMMENT ON COLUMN public.tasks.is_recurring IS 'Whether this is a recurring task';
COMMENT ON COLUMN public.tasks.recurrence_pattern IS 'Recurrence pattern definition';
COMMENT ON COLUMN public.tasks.auto_assign_rules IS 'Automatic assignment rules';
COMMENT ON COLUMN public.tasks.created_at IS 'When the task was created';
COMMENT ON COLUMN public.tasks.updated_at IS 'When the task was last updated';
COMMENT ON COLUMN public.tasks.deleted_at IS 'When the task was soft deleted';

-- Create comprehensive view for tasks with related data
CREATE OR REPLACE VIEW tasks_detailed AS
SELECT 
    t.id,
    t.title,
    t.description,
    t.category,
    t.tags,
    t.status,
    t.priority,
    t.require_task_finished,
    t.require_photo_upload,
    t.require_erp_reference,
    t.can_escalate,
    t.can_reassign,
    t.created_by,
    t.created_by_name,
    t.created_by_role,
    t.department_id,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_departments') 
        THEN (SELECT name FROM hr_departments WHERE id = t.department_id)
        ELSE NULL
    END as department_name,
    t.branch_id,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'branches') 
        THEN (SELECT name FROM branches WHERE id = t.branch_id)
        ELSE NULL
    END as branch_name,
    t.project_id,
    t.template_id,
    t.parent_task_id,
    parent_task.title as parent_task_title,
    t.completion_percentage,
    t.estimated_duration,
    t.actual_duration,
    t.approval_required,
    t.approved_by,
    t.approved_at,
    t.rejection_reason,
    t.external_reference,
    t.metadata,
    t.is_template,
    t.is_recurring,
    t.recurrence_pattern,
    t.auto_assign_rules,
    t.due_date,
    t.due_time,
    t.due_datetime,
    t.created_at,
    t.updated_at,
    t.deleted_at,
    CASE 
        WHEN t.due_datetime IS NOT NULL AND t.due_datetime < now() AND t.status NOT IN ('completed', 'cancelled') THEN true
        ELSE false
    END as is_overdue,
    CASE 
        WHEN t.due_datetime IS NOT NULL THEN 
            EXTRACT(EPOCH FROM (t.due_datetime - now())) / 3600
        ELSE NULL
    END as hours_until_due,
    (SELECT COUNT(*) FROM task_assignments WHERE task_id = t.id) as assignment_count,
    (SELECT COUNT(*) FROM task_images WHERE task_id = t.id AND is_deleted = false) as image_count,
    (SELECT COUNT(*) FROM tasks WHERE parent_task_id = t.id AND deleted_at IS NULL) as subtask_count
FROM tasks t
LEFT JOIN tasks parent_task ON t.parent_task_id = parent_task.id
WHERE t.deleted_at IS NULL
ORDER BY t.created_at DESC;

-- Create function to create a task
CREATE OR REPLACE FUNCTION create_task(
    title_param TEXT,
    description_param TEXT DEFAULT NULL,
    created_by_param TEXT,
    created_by_name_param TEXT DEFAULT NULL,
    created_by_role_param TEXT DEFAULT NULL,
    priority_param TEXT DEFAULT 'medium',
    category_param VARCHAR DEFAULT NULL,
    due_date_param DATE DEFAULT NULL,
    due_time_param TIME DEFAULT NULL,
    require_task_finished_param BOOLEAN DEFAULT false,
    require_photo_upload_param BOOLEAN DEFAULT false,
    require_erp_reference_param BOOLEAN DEFAULT false,
    can_escalate_param BOOLEAN DEFAULT false,
    can_reassign_param BOOLEAN DEFAULT false,
    estimated_duration_param INTERVAL DEFAULT NULL,
    department_id_param BIGINT DEFAULT NULL,
    branch_id_param BIGINT DEFAULT NULL,
    project_id_param UUID DEFAULT NULL,
    parent_task_id_param UUID DEFAULT NULL,
    tags_param TEXT[] DEFAULT NULL,
    metadata_param JSONB DEFAULT '{}',
    approval_required_param BOOLEAN DEFAULT false
)
RETURNS UUID AS $$
DECLARE
    task_id UUID;
    calculated_due_datetime TIMESTAMPTZ;
BEGIN
    -- Calculate due_datetime if due_date is provided
    IF due_date_param IS NOT NULL THEN
        calculated_due_datetime := due_date_param + COALESCE(due_time_param, '23:59:59'::TIME);
    END IF;
    
    INSERT INTO tasks (
        title,
        description,
        created_by,
        created_by_name,
        created_by_role,
        priority,
        category,
        due_date,
        due_time,
        due_datetime,
        require_task_finished,
        require_photo_upload,
        require_erp_reference,
        can_escalate,
        can_reassign,
        estimated_duration,
        department_id,
        branch_id,
        project_id,
        parent_task_id,
        tags,
        metadata,
        approval_required,
        status
    ) VALUES (
        title_param,
        description_param,
        created_by_param,
        created_by_name_param,
        created_by_role_param,
        priority_param,
        category_param,
        due_date_param,
        due_time_param,
        calculated_due_datetime,
        require_task_finished_param,
        require_photo_upload_param,
        require_erp_reference_param,
        can_escalate_param,
        can_reassign_param,
        estimated_duration_param,
        department_id_param,
        branch_id_param,
        project_id_param,
        parent_task_id_param,
        tags_param,
        metadata_param,
        approval_required_param,
        CASE WHEN approval_required_param THEN 'pending' ELSE 'active' END
    ) RETURNING id INTO task_id;
    
    RETURN task_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update task status
CREATE OR REPLACE FUNCTION update_task_status(
    task_id UUID,
    new_status TEXT,
    updated_by TEXT DEFAULT NULL,
    completion_percentage_param INTEGER DEFAULT NULL,
    rejection_reason_param TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE tasks 
    SET status = new_status,
        completion_percentage = COALESCE(completion_percentage_param, 
            CASE 
                WHEN new_status = 'completed' THEN 100
                WHEN new_status = 'in_progress' AND completion_percentage = 0 THEN 10
                ELSE completion_percentage
            END
        ),
        rejection_reason = CASE 
            WHEN new_status IN ('cancelled', 'rejected') THEN rejection_reason_param
            ELSE rejection_reason
        END,
        updated_at = now()
    WHERE id = task_id AND deleted_at IS NULL;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to approve a task
CREATE OR REPLACE FUNCTION approve_task(
    task_id UUID,
    approved_by_param TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE tasks 
    SET status = 'active',
        approved_by = approved_by_param,
        approved_at = now(),
        updated_at = now()
    WHERE id = task_id 
      AND approval_required = true 
      AND status = 'pending'
      AND deleted_at IS NULL;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to soft delete a task
CREATE OR REPLACE FUNCTION delete_task(
    task_id UUID,
    deleted_by TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE tasks 
    SET deleted_at = now(),
        status = 'cancelled',
        updated_at = now()
    WHERE id = task_id AND deleted_at IS NULL;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to search tasks
CREATE OR REPLACE FUNCTION search_tasks(
    search_query TEXT,
    status_filter TEXT DEFAULT NULL,
    priority_filter TEXT DEFAULT NULL,
    created_by_filter TEXT DEFAULT NULL,
    limit_param INTEGER DEFAULT 50
)
RETURNS TABLE(
    task_id UUID,
    title TEXT,
    description TEXT,
    status TEXT,
    priority TEXT,
    created_by TEXT,
    created_by_name TEXT,
    due_datetime TIMESTAMPTZ,
    created_at TIMESTAMPTZ,
    rank REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.title,
        t.description,
        t.status,
        t.priority,
        t.created_by,
        t.created_by_name,
        t.due_datetime,
        t.created_at,
        ts_rank(t.search_vector, plainto_tsquery('english', search_query)) as rank
    FROM tasks t
    WHERE t.deleted_at IS NULL
      AND t.search_vector @@ plainto_tsquery('english', search_query)
      AND (status_filter IS NULL OR t.status = status_filter)
      AND (priority_filter IS NULL OR t.priority = priority_filter)
      AND (created_by_filter IS NULL OR t.created_by = created_by_filter)
    ORDER BY rank DESC, t.created_at DESC
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql;

-- Create function to get task statistics
CREATE OR REPLACE FUNCTION get_task_statistics(
    created_by_filter TEXT DEFAULT NULL,
    department_id_filter BIGINT DEFAULT NULL,
    branch_id_filter BIGINT DEFAULT NULL,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_tasks BIGINT,
    draft_tasks BIGINT,
    active_tasks BIGINT,
    pending_tasks BIGINT,
    in_progress_tasks BIGINT,
    completed_tasks BIGINT,
    cancelled_tasks BIGINT,
    overdue_tasks BIGINT,
    high_priority_tasks BIGINT,
    avg_completion_percentage DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE status = 'draft') as draft_tasks,
        COUNT(*) FILTER (WHERE status = 'active') as active_tasks,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_tasks,
        COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_tasks,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_tasks,
        COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_tasks,
        COUNT(*) FILTER (WHERE due_datetime < now() AND status NOT IN ('completed', 'cancelled')) as overdue_tasks,
        COUNT(*) FILTER (WHERE priority IN ('high', 'urgent', 'critical')) as high_priority_tasks,
        AVG(completion_percentage) as avg_completion_percentage
    FROM tasks
    WHERE deleted_at IS NULL
      AND (created_by_filter IS NULL OR created_by = created_by_filter)
      AND (department_id_filter IS NULL OR department_id = department_id_filter)
      AND (branch_id_filter IS NULL OR branch_id = branch_id_filter)
      AND (date_from IS NULL OR created_at >= date_from)
      AND (date_to IS NULL OR created_at <= date_to);
END;
$$ LANGUAGE plpgsql;

-- Create function to get overdue tasks
CREATE OR REPLACE FUNCTION get_overdue_tasks(
    limit_param INTEGER DEFAULT 50
)
RETURNS TABLE(
    task_id UUID,
    title TEXT,
    priority TEXT,
    due_datetime TIMESTAMPTZ,
    hours_overdue DECIMAL,
    created_by TEXT,
    created_by_name TEXT,
    assignment_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.title,
        t.priority,
        t.due_datetime,
        EXTRACT(EPOCH FROM (now() - t.due_datetime)) / 3600 as hours_overdue,
        t.created_by,
        t.created_by_name,
        (SELECT COUNT(*) FROM task_assignments WHERE task_id = t.id) as assignment_count
    FROM tasks t
    WHERE t.deleted_at IS NULL 
      AND t.due_datetime IS NOT NULL
      AND t.due_datetime < now() 
      AND t.status NOT IN ('completed', 'cancelled')
    ORDER BY t.due_datetime ASC
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'tasks table created with comprehensive task management features';