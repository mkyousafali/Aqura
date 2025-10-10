-- Create quick_tasks table for managing quick task assignments
-- This table is the core table for quick task management system

-- Create the quick_tasks table
CREATE TABLE IF NOT EXISTS public.quick_tasks (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    title CHARACTER VARYING(255) NOT NULL,
    description TEXT NULL,
    price_tag CHARACTER VARYING(50) NULL,
    issue_type CHARACTER VARYING(100) NOT NULL,
    priority CHARACTER VARYING(50) NOT NULL,
    assigned_by UUID NOT NULL,
    assigned_to_branch_id BIGINT NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    deadline_datetime TIMESTAMP WITH TIME ZONE NULL DEFAULT (now() + '24:00:00'::interval),
    completed_at TIMESTAMP WITH TIME ZONE NULL,
    status CHARACTER VARYING(50) NULL DEFAULT 'pending'::character varying,
    created_from CHARACTER VARYING(50) NULL DEFAULT 'quick_task'::character varying,
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    require_task_finished BOOLEAN NULL DEFAULT true,
    require_photo_upload BOOLEAN NULL DEFAULT false,
    require_erp_reference BOOLEAN NULL DEFAULT false,
    
    CONSTRAINT quick_tasks_pkey PRIMARY KEY (id),
    CONSTRAINT quick_tasks_assigned_by_fkey 
        FOREIGN KEY (assigned_by) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT quick_tasks_assigned_to_branch_id_fkey 
        FOREIGN KEY (assigned_to_branch_id) REFERENCES branches (id) ON DELETE SET NULL,
    CONSTRAINT chk_require_task_finished_not_null 
        CHECK (require_task_finished IS NOT NULL)
) TABLESPACE pg_default;

-- Create indexes for efficient queries (original indexes)
CREATE INDEX IF NOT EXISTS idx_quick_tasks_assigned_by 
ON public.quick_tasks USING btree (assigned_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_branch 
ON public.quick_tasks USING btree (assigned_to_branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_status 
ON public.quick_tasks USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_deadline 
ON public.quick_tasks USING btree (deadline_datetime) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_created_at 
ON public.quick_tasks USING btree (created_at) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_issue_type 
ON public.quick_tasks USING btree (issue_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_priority 
ON public.quick_tasks USING btree (priority) 
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_quick_tasks_completed_at 
ON public.quick_tasks (completed_at);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_updated_at 
ON public.quick_tasks (updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_created_from 
ON public.quick_tasks (created_from);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_price_tag 
ON public.quick_tasks (price_tag);

-- Create indexes for completion requirements
CREATE INDEX IF NOT EXISTS idx_quick_tasks_require_photo_upload
ON public.quick_tasks (require_photo_upload) 
WHERE require_photo_upload = true;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_require_erp_reference
ON public.quick_tasks (require_erp_reference) 
WHERE require_erp_reference = true;

-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_quick_tasks_status_priority 
ON public.quick_tasks (status, priority);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_branch_status 
ON public.quick_tasks (assigned_to_branch_id, status);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_assigned_by_status 
ON public.quick_tasks (assigned_by, status);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_deadline_status 
ON public.quick_tasks (deadline_datetime, status) 
WHERE status IN ('pending', 'in_progress');

CREATE INDEX IF NOT EXISTS idx_quick_tasks_overdue 
ON public.quick_tasks (deadline_datetime, status) 
WHERE deadline_datetime < now() AND status NOT IN ('completed', 'cancelled');

-- Create partial indexes for performance
CREATE INDEX IF NOT EXISTS idx_quick_tasks_active 
ON public.quick_tasks (created_at DESC) 
WHERE status IN ('pending', 'in_progress', 'review');

CREATE INDEX IF NOT EXISTS idx_quick_tasks_high_priority 
ON public.quick_tasks (deadline_datetime) 
WHERE priority IN ('high', 'urgent', 'critical');

-- Create text search index for title and description
CREATE INDEX IF NOT EXISTS idx_quick_tasks_text_search 
ON public.quick_tasks USING gin (to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(description, '')));

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_quick_tasks_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_quick_tasks_updated_at 
BEFORE UPDATE ON quick_tasks 
FOR EACH ROW 
EXECUTE FUNCTION update_quick_tasks_updated_at();

-- Add data validation constraints
ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_title_not_empty 
CHECK (TRIM(title) != '');

ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_status_valid 
CHECK (status IN (
    'pending', 'in_progress', 'review', 'completed', 'cancelled', 'on_hold'
));

ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_priority_valid 
CHECK (priority IN (
    'low', 'medium', 'high', 'urgent', 'critical'
));

ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_issue_type_valid 
CHECK (issue_type IN (
    'bug', 'feature', 'improvement', 'task', 'maintenance', 'urgent', 'other'
));

ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_created_from_valid 
CHECK (created_from IN (
    'quick_task', 'template', 'import', 'api', 'mobile', 'web', 'system'
));

ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_deadline_after_creation 
CHECK (deadline_datetime >= created_at);

ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_completed_at_valid 
CHECK (completed_at IS NULL OR completed_at >= created_at);

-- Add additional columns for enhanced functionality
ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS estimated_hours DECIMAL(5,2);

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS actual_hours DECIMAL(5,2);

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS department_id BIGINT;

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS tags TEXT[];

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT false;

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS recurrence_pattern JSONB;

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS parent_task_id UUID;

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS progress_percentage INTEGER DEFAULT 0;

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS reminder_datetime TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS started_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.quick_tasks 
ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT now();

-- Add foreign keys for new columns
ALTER TABLE public.quick_tasks 
ADD CONSTRAINT quick_tasks_parent_task_id_fkey 
FOREIGN KEY (parent_task_id) REFERENCES quick_tasks (id) ON DELETE CASCADE;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_departments') THEN
        ALTER TABLE public.quick_tasks 
        ADD CONSTRAINT quick_tasks_department_id_fkey 
        FOREIGN KEY (department_id) REFERENCES hr_departments (id) ON DELETE SET NULL;
    END IF;
END $$;

-- Add validation for new columns
ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_estimated_hours_positive 
CHECK (estimated_hours IS NULL OR estimated_hours > 0);

ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_actual_hours_positive 
CHECK (actual_hours IS NULL OR actual_hours > 0);

ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_progress_percentage_valid 
CHECK (progress_percentage >= 0 AND progress_percentage <= 100);

ALTER TABLE public.quick_tasks 
ADD CONSTRAINT chk_started_at_valid 
CHECK (started_at IS NULL OR started_at >= created_at);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_quick_tasks_department 
ON public.quick_tasks (department_id);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_parent_task 
ON public.quick_tasks (parent_task_id);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_reminder 
ON public.quick_tasks (reminder_datetime) 
WHERE reminder_datetime IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_progress 
ON public.quick_tasks (progress_percentage);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_recurring 
ON public.quick_tasks (is_recurring) 
WHERE is_recurring = true;

CREATE INDEX IF NOT EXISTS idx_quick_tasks_last_activity 
ON public.quick_tasks (last_activity_at DESC);

-- Create GIN indexes for arrays and JSONB
CREATE INDEX IF NOT EXISTS idx_quick_tasks_tags 
ON public.quick_tasks USING gin (tags);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_metadata 
ON public.quick_tasks USING gin (metadata);

CREATE INDEX IF NOT EXISTS idx_quick_tasks_recurrence 
ON public.quick_tasks USING gin (recurrence_pattern);

-- Add table and column comments
COMMENT ON TABLE public.quick_tasks IS 'Core table for quick task management with comprehensive features';
COMMENT ON COLUMN public.quick_tasks.id IS 'Unique identifier for the task';
COMMENT ON COLUMN public.quick_tasks.title IS 'Task title/name';
COMMENT ON COLUMN public.quick_tasks.description IS 'Detailed task description';
COMMENT ON COLUMN public.quick_tasks.price_tag IS 'Price tag or cost category';
COMMENT ON COLUMN public.quick_tasks.issue_type IS 'Type of issue (bug, feature, etc.)';
COMMENT ON COLUMN public.quick_tasks.priority IS 'Task priority level';
COMMENT ON COLUMN public.quick_tasks.assigned_by IS 'User who assigned the task';
COMMENT ON COLUMN public.quick_tasks.assigned_to_branch_id IS 'Branch assigned to handle the task';
COMMENT ON COLUMN public.quick_tasks.deadline_datetime IS 'Task deadline';
COMMENT ON COLUMN public.quick_tasks.completed_at IS 'When the task was completed';
COMMENT ON COLUMN public.quick_tasks.status IS 'Current task status';
COMMENT ON COLUMN public.quick_tasks.created_from IS 'Source of task creation';
COMMENT ON COLUMN public.quick_tasks.estimated_hours IS 'Estimated hours to complete';
COMMENT ON COLUMN public.quick_tasks.actual_hours IS 'Actual hours spent';
COMMENT ON COLUMN public.quick_tasks.department_id IS 'Department responsible for the task';
COMMENT ON COLUMN public.quick_tasks.tags IS 'Array of tags for categorization';
COMMENT ON COLUMN public.quick_tasks.metadata IS 'Additional metadata as JSON';
COMMENT ON COLUMN public.quick_tasks.is_recurring IS 'Whether this is a recurring task';
COMMENT ON COLUMN public.quick_tasks.recurrence_pattern IS 'Recurrence pattern definition';
COMMENT ON COLUMN public.quick_tasks.parent_task_id IS 'Parent task for subtasks';
COMMENT ON COLUMN public.quick_tasks.progress_percentage IS 'Task completion percentage (0-100)';
COMMENT ON COLUMN public.quick_tasks.reminder_datetime IS 'When to send reminder';
COMMENT ON COLUMN public.quick_tasks.started_at IS 'When work on the task started';
COMMENT ON COLUMN public.quick_tasks.last_activity_at IS 'Last activity timestamp';
COMMENT ON COLUMN public.quick_tasks.created_at IS 'When the task was created';
COMMENT ON COLUMN public.quick_tasks.updated_at IS 'When the task was last updated';
COMMENT ON COLUMN public.quick_tasks.require_task_finished IS 'Default requirement for task completion (always required)';
COMMENT ON COLUMN public.quick_tasks.require_photo_upload IS 'Default requirement for photo upload on task completion';
COMMENT ON COLUMN public.quick_tasks.require_erp_reference IS 'Default requirement for ERP reference on task completion';

-- Create comprehensive view for tasks with related data
CREATE OR REPLACE VIEW quick_tasks_detailed AS
SELECT 
    qt.id,
    qt.title,
    qt.description,
    qt.price_tag,
    qt.issue_type,
    qt.priority,
    qt.status,
    qt.assigned_by,
    assigner.username as assigned_by_username,
    assigner.full_name as assigned_by_name,
    qt.assigned_to_branch_id,
    b.name as assigned_to_branch_name,
    qt.department_id,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'hr_departments') 
        THEN (SELECT name FROM hr_departments WHERE id = qt.department_id)
        ELSE NULL
    END as department_name,
    qt.parent_task_id,
    parent_task.title as parent_task_title,
    qt.estimated_hours,
    qt.actual_hours,
    qt.progress_percentage,
    qt.tags,
    qt.metadata,
    qt.is_recurring,
    qt.recurrence_pattern,
    qt.created_from,
    qt.reminder_datetime,
    qt.deadline_datetime,
    qt.started_at,
    qt.completed_at,
    qt.last_activity_at,
    qt.created_at,
    qt.updated_at,
    qt.require_task_finished,
    qt.require_photo_upload,
    qt.require_erp_reference,
    CASE 
        WHEN qt.deadline_datetime < now() AND qt.status NOT IN ('completed', 'cancelled') THEN true
        ELSE false
    END as is_overdue,
    CASE 
        WHEN qt.deadline_datetime < now() + INTERVAL '24 hours' AND qt.status NOT IN ('completed', 'cancelled') THEN true
        ELSE false
    END as is_due_soon,
    EXTRACT(EPOCH FROM (qt.deadline_datetime - now())) / 3600 as hours_until_deadline,
    (SELECT COUNT(*) FROM quick_task_assignments WHERE quick_task_id = qt.id) as assignment_count,
    (SELECT COUNT(*) FROM quick_task_comments WHERE quick_task_id = qt.id AND is_deleted = false) as comment_count,
    (SELECT COUNT(*) FROM quick_task_files WHERE quick_task_id = qt.id AND is_deleted = false) as file_count
FROM quick_tasks qt
LEFT JOIN users assigner ON qt.assigned_by = assigner.id
LEFT JOIN branches b ON qt.assigned_to_branch_id = b.id
LEFT JOIN quick_tasks parent_task ON qt.parent_task_id = parent_task.id
ORDER BY qt.created_at DESC;

-- Create function to create a quick task
CREATE OR REPLACE FUNCTION create_quick_task(
    title_param VARCHAR,
    description_param TEXT DEFAULT NULL,
    issue_type_param VARCHAR,
    priority_param VARCHAR,
    assigned_by_param UUID,
    assigned_to_branch_id_param BIGINT DEFAULT NULL,
    deadline_param TIMESTAMPTZ DEFAULT NULL,
    price_tag_param VARCHAR DEFAULT NULL,
    estimated_hours_param DECIMAL DEFAULT NULL,
    department_id_param BIGINT DEFAULT NULL,
    tags_param TEXT[] DEFAULT NULL,
    metadata_param JSONB DEFAULT '{}',
    parent_task_id_param UUID DEFAULT NULL,
    require_task_finished_param BOOLEAN DEFAULT true,
    require_photo_upload_param BOOLEAN DEFAULT false,
    require_erp_reference_param BOOLEAN DEFAULT false
)
RETURNS UUID AS $$
DECLARE
    task_id UUID;
    calculated_deadline TIMESTAMPTZ;
BEGIN
    -- Calculate deadline if not provided
    calculated_deadline := COALESCE(deadline_param, now() + INTERVAL '24 hours');
    
    INSERT INTO quick_tasks (
        title,
        description,
        issue_type,
        priority,
        assigned_by,
        assigned_to_branch_id,
        deadline_datetime,
        price_tag,
        estimated_hours,
        department_id,
        tags,
        metadata,
        parent_task_id,
        require_task_finished,
        require_photo_upload,
        require_erp_reference
    ) VALUES (
        title_param,
        description_param,
        issue_type_param,
        priority_param,
        assigned_by_param,
        assigned_to_branch_id_param,
        calculated_deadline,
        price_tag_param,
        estimated_hours_param,
        department_id_param,
        tags_param,
        metadata_param,
        parent_task_id_param,
        require_task_finished_param,
        require_photo_upload_param,
        require_erp_reference_param
    ) RETURNING id INTO task_id;
    
    RETURN task_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update task status
CREATE OR REPLACE FUNCTION update_task_status(
    task_id UUID,
    new_status VARCHAR,
    updated_by UUID DEFAULT NULL,
    progress_param INTEGER DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    old_status VARCHAR;
BEGIN
    -- Get current status
    SELECT status INTO old_status FROM quick_tasks WHERE id = task_id;
    
    IF old_status IS NULL THEN
        RETURN false;
    END IF;
    
    -- Update task
    UPDATE quick_tasks 
    SET status = new_status,
        progress_percentage = COALESCE(progress_param, 
            CASE 
                WHEN new_status = 'completed' THEN 100
                WHEN new_status = 'in_progress' AND progress_percentage = 0 THEN 10
                ELSE progress_percentage
            END
        ),
        started_at = CASE 
            WHEN new_status = 'in_progress' AND started_at IS NULL THEN now()
            ELSE started_at
        END,
        completed_at = CASE 
            WHEN new_status = 'completed' THEN now()
            WHEN new_status != 'completed' THEN NULL
            ELSE completed_at
        END,
        last_activity_at = now(),
        updated_at = now()
    WHERE id = task_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get task statistics
CREATE OR REPLACE FUNCTION get_task_statistics(
    branch_id_param BIGINT DEFAULT NULL,
    department_id_param BIGINT DEFAULT NULL,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_tasks BIGINT,
    pending_tasks BIGINT,
    in_progress_tasks BIGINT,
    completed_tasks BIGINT,
    overdue_tasks BIGINT,
    high_priority_tasks BIGINT,
    avg_completion_hours DECIMAL,
    avg_progress_percentage DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_tasks,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_tasks,
        COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_tasks,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_tasks,
        COUNT(*) FILTER (WHERE deadline_datetime < now() AND status NOT IN ('completed', 'cancelled')) as overdue_tasks,
        COUNT(*) FILTER (WHERE priority IN ('high', 'urgent', 'critical')) as high_priority_tasks,
        AVG(actual_hours) FILTER (WHERE actual_hours IS NOT NULL) as avg_completion_hours,
        AVG(progress_percentage) as avg_progress_percentage
    FROM quick_tasks
    WHERE (branch_id_param IS NULL OR assigned_to_branch_id = branch_id_param)
      AND (department_id_param IS NULL OR department_id = department_id_param)
      AND (date_from IS NULL OR created_at >= date_from)
      AND (date_to IS NULL OR created_at <= date_to);
END;
$$ LANGUAGE plpgsql;

-- Create function to get overdue tasks
CREATE OR REPLACE FUNCTION get_overdue_tasks(
    branch_id_param BIGINT DEFAULT NULL,
    limit_param INTEGER DEFAULT 50
)
RETURNS TABLE(
    task_id UUID,
    title VARCHAR,
    priority VARCHAR,
    assigned_to_branch VARCHAR,
    deadline_datetime TIMESTAMPTZ,
    hours_overdue DECIMAL,
    assigned_by_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        qt.id,
        qt.title,
        qt.priority,
        b.name as assigned_to_branch,
        qt.deadline_datetime,
        EXTRACT(EPOCH FROM (now() - qt.deadline_datetime)) / 3600 as hours_overdue,
        COALESCE(u.full_name, u.username) as assigned_by_name
    FROM quick_tasks qt
    LEFT JOIN branches b ON qt.assigned_to_branch_id = b.id
    LEFT JOIN users u ON qt.assigned_by = u.id
    WHERE qt.deadline_datetime < now() 
      AND qt.status NOT IN ('completed', 'cancelled')
      AND (branch_id_param IS NULL OR qt.assigned_to_branch_id = branch_id_param)
    ORDER BY qt.deadline_datetime ASC
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update last_activity_at on related table changes
CREATE OR REPLACE FUNCTION update_task_last_activity()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE quick_tasks 
    SET last_activity_at = now()
    WHERE id = COALESCE(NEW.quick_task_id, OLD.quick_task_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'quick_tasks table created with comprehensive task management features';