-- Create task_assignments table for managing task assignments to users and branches
-- This table handles the assignment of tasks with scheduling, deadlines, and recurring patterns

-- Create the task_assignments table
CREATE TABLE IF NOT EXISTS public.task_assignments (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL,
    assignment_type TEXT NOT NULL,
    assigned_to_user_id TEXT NULL,
    assigned_to_branch_id UUID NULL,
    assigned_by TEXT NOT NULL,
    assigned_by_name TEXT NULL,
    assigned_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    status TEXT NULL DEFAULT 'assigned'::text,
    started_at TIMESTAMP WITH TIME ZONE NULL,
    completed_at TIMESTAMP WITH TIME ZONE NULL,
    schedule_date DATE NULL,
    schedule_time TIME WITHOUT TIME ZONE NULL,
    deadline_date DATE NULL,
    deadline_time TIME WITHOUT TIME ZONE NULL,
    deadline_datetime TIMESTAMP WITH TIME ZONE NULL,
    is_reassignable BOOLEAN NULL DEFAULT true,
    is_recurring BOOLEAN NULL DEFAULT false,
    recurring_pattern JSONB NULL,
    notes TEXT NULL,
    priority_override TEXT NULL,
    require_task_finished BOOLEAN NULL DEFAULT true,
    require_photo_upload BOOLEAN NULL DEFAULT false,
    require_erp_reference BOOLEAN NULL DEFAULT false,
    reassigned_from UUID NULL,
    reassignment_reason TEXT NULL,
    reassigned_at TIMESTAMP WITH TIME ZONE NULL,
    
    CONSTRAINT task_assignments_pkey PRIMARY KEY (id),
    CONSTRAINT task_assignments_task_id_assignment_type_assigned_to_user_i_key 
        UNIQUE (task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id),
    CONSTRAINT fk_task_assignments_reassigned_from 
        FOREIGN KEY (reassigned_from) REFERENCES task_assignments (id) ON DELETE SET NULL,
    CONSTRAINT task_assignments_task_id_fkey 
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT chk_schedule_consistency 
        CHECK ((schedule_date IS NULL AND schedule_time IS NULL) OR (schedule_date IS NOT NULL)),
    CONSTRAINT chk_priority_override_valid 
        CHECK (priority_override IS NULL OR priority_override = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'urgent'::text])),
    CONSTRAINT chk_deadline_consistency 
        CHECK ((deadline_date IS NULL AND deadline_time IS NULL) OR (deadline_date IS NOT NULL))
) TABLESPACE pg_default;

-- Create indexes for efficient queries (original indexes)
CREATE INDEX IF NOT EXISTS idx_task_assignments_task_id 
ON public.task_assignments USING btree (task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_user_id 
ON public.task_assignments USING btree (assigned_to_user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_branch_id 
ON public.task_assignments USING btree (assigned_to_branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assignment_type 
ON public.task_assignments USING btree (assignment_type) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_status 
ON public.task_assignments USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_by 
ON public.task_assignments USING btree (assigned_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_deadline_datetime 
ON public.task_assignments USING btree (deadline_datetime) 
TABLESPACE pg_default
WHERE deadline_datetime IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_assignments_schedule_date 
ON public.task_assignments USING btree (schedule_date) 
TABLESPACE pg_default
WHERE schedule_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_assignments_recurring 
ON public.task_assignments USING btree (is_recurring, status) 
TABLESPACE pg_default
WHERE is_recurring = true;

CREATE INDEX IF NOT EXISTS idx_task_assignments_reassignable 
ON public.task_assignments USING btree (is_reassignable, status) 
TABLESPACE pg_default
WHERE is_reassignable = true;

CREATE INDEX IF NOT EXISTS idx_task_assignments_overdue 
ON public.task_assignments USING btree (deadline_datetime, status) 
TABLESPACE pg_default
WHERE deadline_datetime IS NOT NULL AND status <> ALL (ARRAY['completed'::text, 'cancelled'::text]);

-- Create original triggers
CREATE TRIGGER cleanup_assignment_notifications_trigger
AFTER DELETE ON task_assignments 
FOR EACH ROW 
EXECUTE FUNCTION trigger_cleanup_assignment_notifications();

CREATE TRIGGER trigger_update_deadline_datetime 
BEFORE INSERT OR UPDATE OF deadline_date, deadline_time ON task_assignments 
FOR EACH ROW 
EXECUTE FUNCTION update_deadline_datetime();

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_at 
ON public.task_assignments (assigned_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_assignments_started_at 
ON public.task_assignments (started_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_assignments_completed_at 
ON public.task_assignments (completed_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_assignments_reassigned_from 
ON public.task_assignments (reassigned_from);

CREATE INDEX IF NOT EXISTS idx_task_assignments_reassigned_at 
ON public.task_assignments (reassigned_at DESC);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_task_assignments_user_status 
ON public.task_assignments (assigned_to_user_id, status);

CREATE INDEX IF NOT EXISTS idx_task_assignments_branch_status 
ON public.task_assignments (assigned_to_branch_id, status);

CREATE INDEX IF NOT EXISTS idx_task_assignments_type_status 
ON public.task_assignments (assignment_type, status);

CREATE INDEX IF NOT EXISTS idx_task_assignments_schedule_status 
ON public.task_assignments (schedule_date, status) 
WHERE schedule_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_assignments_priority_deadline 
ON public.task_assignments (priority_override, deadline_datetime) 
WHERE priority_override IS NOT NULL;

-- Create partial indexes for performance
CREATE INDEX IF NOT EXISTS idx_task_assignments_active 
ON public.task_assignments (assigned_at DESC) 
WHERE status IN ('assigned', 'in_progress', 'pending');

CREATE INDEX IF NOT EXISTS idx_task_assignments_requires_photo 
ON public.task_assignments (task_id, assigned_to_user_id) 
WHERE require_photo_upload = true;

CREATE INDEX IF NOT EXISTS idx_task_assignments_requires_erp 
ON public.task_assignments (task_id, assigned_to_user_id) 
WHERE require_erp_reference = true;

-- Create GIN index for recurring_pattern JSONB
CREATE INDEX IF NOT EXISTS idx_task_assignments_recurring_pattern 
ON public.task_assignments USING gin (recurring_pattern);

-- Add updated_at column and trigger
ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_task_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_task_assignments_updated_at 
BEFORE UPDATE ON task_assignments 
FOR EACH ROW 
EXECUTE FUNCTION update_task_assignments_updated_at();

-- Add additional validation constraints
ALTER TABLE public.task_assignments 
ADD CONSTRAINT chk_status_valid 
CHECK (status IN (
    'assigned', 'pending', 'in_progress', 'review', 'completed', 'cancelled', 'overdue', 'rejected'
));

ALTER TABLE public.task_assignments 
ADD CONSTRAINT chk_assignment_type_valid 
CHECK (assignment_type IN (
    'primary', 'secondary', 'backup', 'review', 'approval', 'notification', 'escalation'
));

ALTER TABLE public.task_assignments 
ADD CONSTRAINT chk_assignment_target 
CHECK (assigned_to_user_id IS NOT NULL OR assigned_to_branch_id IS NOT NULL);

ALTER TABLE public.task_assignments 
ADD CONSTRAINT chk_completion_sequence 
CHECK (completed_at IS NULL OR completed_at >= COALESCE(started_at, assigned_at));

ALTER TABLE public.task_assignments 
ADD CONSTRAINT chk_start_sequence 
CHECK (started_at IS NULL OR started_at >= assigned_at);

-- Add additional columns for enhanced functionality
ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS estimated_duration INTERVAL;

ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS actual_duration INTERVAL;

ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS progress_percentage INTEGER DEFAULT 0;

ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT now();

ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';

ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS external_reference VARCHAR(255);

ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS completion_notes TEXT;

ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS escalation_level INTEGER DEFAULT 0;

ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS notification_settings JSONB DEFAULT '{}';

-- Add validation for new columns
ALTER TABLE public.task_assignments 
ADD CONSTRAINT chk_progress_percentage_valid 
CHECK (progress_percentage >= 0 AND progress_percentage <= 100);

ALTER TABLE public.task_assignments 
ADD CONSTRAINT chk_escalation_level_valid 
CHECK (escalation_level >= 0 AND escalation_level <= 5);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_task_assignments_progress 
ON public.task_assignments (progress_percentage);

CREATE INDEX IF NOT EXISTS idx_task_assignments_last_activity 
ON public.task_assignments (last_activity_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_assignments_external_ref 
ON public.task_assignments (external_reference);

CREATE INDEX IF NOT EXISTS idx_task_assignments_escalation 
ON public.task_assignments (escalation_level) 
WHERE escalation_level > 0;

CREATE INDEX IF NOT EXISTS idx_task_assignments_reminder 
ON public.task_assignments (reminder_sent_at) 
WHERE reminder_sent_at IS NOT NULL;

-- Create GIN indexes for JSONB columns
CREATE INDEX IF NOT EXISTS idx_task_assignments_metadata 
ON public.task_assignments USING gin (metadata);

CREATE INDEX IF NOT EXISTS idx_task_assignments_notification_settings 
ON public.task_assignments USING gin (notification_settings);

-- Add table and column comments
COMMENT ON TABLE public.task_assignments IS 'Task assignments to users and branches with scheduling and tracking capabilities';
COMMENT ON COLUMN public.task_assignments.id IS 'Unique identifier for the assignment';
COMMENT ON COLUMN public.task_assignments.task_id IS 'Reference to the task being assigned';
COMMENT ON COLUMN public.task_assignments.assignment_type IS 'Type of assignment (primary, secondary, etc.)';
COMMENT ON COLUMN public.task_assignments.assigned_to_user_id IS 'User assigned to the task';
COMMENT ON COLUMN public.task_assignments.assigned_to_branch_id IS 'Branch assigned to the task';
COMMENT ON COLUMN public.task_assignments.assigned_by IS 'User who made the assignment';
COMMENT ON COLUMN public.task_assignments.assigned_by_name IS 'Name of the user who made the assignment';
COMMENT ON COLUMN public.task_assignments.assigned_at IS 'When the assignment was made';
COMMENT ON COLUMN public.task_assignments.status IS 'Current status of the assignment';
COMMENT ON COLUMN public.task_assignments.started_at IS 'When work on the assignment started';
COMMENT ON COLUMN public.task_assignments.completed_at IS 'When the assignment was completed';
COMMENT ON COLUMN public.task_assignments.schedule_date IS 'Scheduled date for the assignment';
COMMENT ON COLUMN public.task_assignments.schedule_time IS 'Scheduled time for the assignment';
COMMENT ON COLUMN public.task_assignments.deadline_date IS 'Deadline date for the assignment';
COMMENT ON COLUMN public.task_assignments.deadline_time IS 'Deadline time for the assignment';
COMMENT ON COLUMN public.task_assignments.deadline_datetime IS 'Combined deadline datetime';
COMMENT ON COLUMN public.task_assignments.is_reassignable IS 'Whether the assignment can be reassigned';
COMMENT ON COLUMN public.task_assignments.is_recurring IS 'Whether this is a recurring assignment';
COMMENT ON COLUMN public.task_assignments.recurring_pattern IS 'Pattern for recurring assignments';
COMMENT ON COLUMN public.task_assignments.notes IS 'Additional notes for the assignment';
COMMENT ON COLUMN public.task_assignments.priority_override IS 'Override priority for this assignment';
COMMENT ON COLUMN public.task_assignments.require_task_finished IS 'Whether task completion is required';
COMMENT ON COLUMN public.task_assignments.require_photo_upload IS 'Whether photo upload is required';
COMMENT ON COLUMN public.task_assignments.require_erp_reference IS 'Whether ERP reference is required';
COMMENT ON COLUMN public.task_assignments.reassigned_from IS 'Previous assignment this was reassigned from';
COMMENT ON COLUMN public.task_assignments.reassignment_reason IS 'Reason for reassignment';
COMMENT ON COLUMN public.task_assignments.reassigned_at IS 'When the reassignment was made';
COMMENT ON COLUMN public.task_assignments.estimated_duration IS 'Estimated time to complete';
COMMENT ON COLUMN public.task_assignments.actual_duration IS 'Actual time taken to complete';
COMMENT ON COLUMN public.task_assignments.progress_percentage IS 'Progress percentage (0-100)';
COMMENT ON COLUMN public.task_assignments.last_activity_at IS 'Last activity timestamp';
COMMENT ON COLUMN public.task_assignments.metadata IS 'Additional metadata as JSON';
COMMENT ON COLUMN public.task_assignments.external_reference IS 'External system reference';
COMMENT ON COLUMN public.task_assignments.completion_notes IS 'Notes added upon completion';
COMMENT ON COLUMN public.task_assignments.rejection_reason IS 'Reason for rejection if applicable';
COMMENT ON COLUMN public.task_assignments.escalation_level IS 'Current escalation level (0-5)';
COMMENT ON COLUMN public.task_assignments.reminder_sent_at IS 'When last reminder was sent';
COMMENT ON COLUMN public.task_assignments.notification_settings IS 'Notification preferences as JSON';
COMMENT ON COLUMN public.task_assignments.updated_at IS 'When the assignment was last updated';

-- Create comprehensive view for assignments with task details
CREATE OR REPLACE VIEW task_assignments_detailed AS
SELECT 
    ta.id,
    ta.task_id,
    t.name as task_name,
    t.description as task_description,
    ta.assignment_type,
    ta.assigned_to_user_id,
    ta.assigned_to_branch_id,
    b.name as assigned_to_branch_name,
    ta.assigned_by,
    ta.assigned_by_name,
    ta.status,
    ta.schedule_date,
    ta.schedule_time,
    ta.deadline_date,
    ta.deadline_time,
    ta.deadline_datetime,
    ta.is_reassignable,
    ta.is_recurring,
    ta.recurring_pattern,
    ta.notes,
    ta.priority_override,
    COALESCE(ta.priority_override, t.priority) as effective_priority,
    ta.require_task_finished,
    ta.require_photo_upload,
    ta.require_erp_reference,
    ta.reassigned_from,
    ta.reassignment_reason,
    ta.estimated_duration,
    ta.actual_duration,
    ta.progress_percentage,
    ta.external_reference,
    ta.completion_notes,
    ta.rejection_reason,
    ta.escalation_level,
    ta.metadata,
    ta.assigned_at,
    ta.started_at,
    ta.completed_at,
    ta.reassigned_at,
    ta.reminder_sent_at,
    ta.last_activity_at,
    ta.updated_at,
    CASE 
        WHEN ta.deadline_datetime IS NOT NULL AND ta.deadline_datetime < now() AND ta.status NOT IN ('completed', 'cancelled') THEN true
        ELSE false
    END as is_overdue,
    CASE 
        WHEN ta.deadline_datetime IS NOT NULL THEN 
            EXTRACT(EPOCH FROM (ta.deadline_datetime - now())) / 3600
        ELSE NULL
    END as hours_until_deadline,
    CASE 
        WHEN ta.completed_at IS NOT NULL AND ta.started_at IS NOT NULL THEN 
            ta.completed_at - ta.started_at
        ELSE NULL
    END as total_time_taken
FROM task_assignments ta
LEFT JOIN tasks t ON ta.task_id = t.id
LEFT JOIN branches b ON ta.assigned_to_branch_id = b.id
ORDER BY ta.assigned_at DESC;

-- Create function to assign a task
CREATE OR REPLACE FUNCTION assign_task(
    task_id_param UUID,
    assignment_type_param TEXT,
    assigned_to_user_id_param TEXT DEFAULT NULL,
    assigned_to_branch_id_param UUID DEFAULT NULL,
    assigned_by_param TEXT,
    assigned_by_name_param TEXT DEFAULT NULL,
    schedule_date_param DATE DEFAULT NULL,
    schedule_time_param TIME DEFAULT NULL,
    deadline_date_param DATE DEFAULT NULL,
    deadline_time_param TIME DEFAULT NULL,
    priority_override_param TEXT DEFAULT NULL,
    notes_param TEXT DEFAULT NULL,
    require_photo_upload_param BOOLEAN DEFAULT false,
    require_erp_reference_param BOOLEAN DEFAULT false,
    metadata_param JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO task_assignments (
        task_id,
        assignment_type,
        assigned_to_user_id,
        assigned_to_branch_id,
        assigned_by,
        assigned_by_name,
        schedule_date,
        schedule_time,
        deadline_date,
        deadline_time,
        priority_override,
        notes,
        require_photo_upload,
        require_erp_reference,
        metadata
    ) VALUES (
        task_id_param,
        assignment_type_param,
        assigned_to_user_id_param,
        assigned_to_branch_id_param,
        assigned_by_param,
        assigned_by_name_param,
        schedule_date_param,
        schedule_time_param,
        deadline_date_param,
        deadline_time_param,
        priority_override_param,
        notes_param,
        require_photo_upload_param,
        require_erp_reference_param,
        metadata_param
    ) RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update assignment status
CREATE OR REPLACE FUNCTION update_assignment_status(
    assignment_id UUID,
    new_status TEXT,
    progress_param INTEGER DEFAULT NULL,
    completion_notes_param TEXT DEFAULT NULL,
    rejection_reason_param TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE task_assignments 
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
        completion_notes = COALESCE(completion_notes_param, completion_notes),
        rejection_reason = COALESCE(rejection_reason_param, rejection_reason),
        last_activity_at = now(),
        updated_at = now()
    WHERE id = assignment_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to reassign task
CREATE OR REPLACE FUNCTION reassign_task(
    assignment_id UUID,
    new_assigned_to_user_id TEXT DEFAULT NULL,
    new_assigned_to_branch_id UUID DEFAULT NULL,
    reassigned_by TEXT,
    reassignment_reason_param TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    old_assignment RECORD;
    new_assignment_id UUID;
BEGIN
    -- Get the current assignment
    SELECT * INTO old_assignment FROM task_assignments WHERE id = assignment_id;
    
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    
    -- Create new assignment
    INSERT INTO task_assignments (
        task_id,
        assignment_type,
        assigned_to_user_id,
        assigned_to_branch_id,
        assigned_by,
        schedule_date,
        schedule_time,
        deadline_date,
        deadline_time,
        priority_override,
        notes,
        require_task_finished,
        require_photo_upload,
        require_erp_reference,
        reassigned_from,
        reassignment_reason,
        reassigned_at,
        metadata
    ) VALUES (
        old_assignment.task_id,
        old_assignment.assignment_type,
        COALESCE(new_assigned_to_user_id, old_assignment.assigned_to_user_id),
        COALESCE(new_assigned_to_branch_id, old_assignment.assigned_to_branch_id),
        reassigned_by,
        old_assignment.schedule_date,
        old_assignment.schedule_time,
        old_assignment.deadline_date,
        old_assignment.deadline_time,
        old_assignment.priority_override,
        old_assignment.notes,
        old_assignment.require_task_finished,
        old_assignment.require_photo_upload,
        old_assignment.require_erp_reference,
        assignment_id,
        reassignment_reason_param,
        now(),
        old_assignment.metadata
    ) RETURNING id INTO new_assignment_id;
    
    -- Mark old assignment as reassigned
    UPDATE task_assignments 
    SET status = 'reassigned',
        last_activity_at = now(),
        updated_at = now()
    WHERE id = assignment_id;
    
    RETURN new_assignment_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to get overdue assignments
CREATE OR REPLACE FUNCTION get_overdue_assignments(
    user_id_param TEXT DEFAULT NULL,
    branch_id_param UUID DEFAULT NULL,
    limit_param INTEGER DEFAULT 50
)
RETURNS TABLE(
    assignment_id UUID,
    task_name VARCHAR,
    assigned_to_user_id TEXT,
    assigned_to_branch_name VARCHAR,
    deadline_datetime TIMESTAMPTZ,
    hours_overdue DECIMAL,
    escalation_level INTEGER,
    priority VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ta.id,
        t.name as task_name,
        ta.assigned_to_user_id,
        b.name as assigned_to_branch_name,
        ta.deadline_datetime,
        EXTRACT(EPOCH FROM (now() - ta.deadline_datetime)) / 3600 as hours_overdue,
        ta.escalation_level,
        COALESCE(ta.priority_override, t.priority) as priority
    FROM task_assignments ta
    LEFT JOIN tasks t ON ta.task_id = t.id
    LEFT JOIN branches b ON ta.assigned_to_branch_id = b.id
    WHERE ta.deadline_datetime IS NOT NULL 
      AND ta.deadline_datetime < now() 
      AND ta.status NOT IN ('completed', 'cancelled', 'reassigned')
      AND (user_id_param IS NULL OR ta.assigned_to_user_id = user_id_param)
      AND (branch_id_param IS NULL OR ta.assigned_to_branch_id = branch_id_param)
    ORDER BY ta.deadline_datetime ASC
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql;

-- Create function to get assignment statistics
CREATE OR REPLACE FUNCTION get_assignment_statistics(
    user_id_param TEXT DEFAULT NULL,
    branch_id_param UUID DEFAULT NULL,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_assignments BIGINT,
    pending_assignments BIGINT,
    in_progress_assignments BIGINT,
    completed_assignments BIGINT,
    overdue_assignments BIGINT,
    avg_completion_time INTERVAL,
    avg_progress_percentage DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_assignments,
        COUNT(*) FILTER (WHERE status IN ('assigned', 'pending')) as pending_assignments,
        COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_assignments,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_assignments,
        COUNT(*) FILTER (WHERE deadline_datetime < now() AND status NOT IN ('completed', 'cancelled')) as overdue_assignments,
        AVG(completed_at - started_at) FILTER (WHERE completed_at IS NOT NULL AND started_at IS NOT NULL) as avg_completion_time,
        AVG(progress_percentage) as avg_progress_percentage
    FROM task_assignments
    WHERE (user_id_param IS NULL OR assigned_to_user_id = user_id_param)
      AND (branch_id_param IS NULL OR assigned_to_branch_id = branch_id_param)
      AND (date_from IS NULL OR assigned_at >= date_from)
      AND (date_to IS NULL OR assigned_at <= date_to);
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'task_assignments table created with comprehensive assignment management features';