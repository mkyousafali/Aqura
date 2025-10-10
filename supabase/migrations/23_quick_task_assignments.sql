-- Create quick_task_assignments table for managing quick task assignments to users
-- This table tracks assignment status and completion progress for quick tasks

-- Create the quick_task_assignments table
CREATE TABLE IF NOT EXISTS public.quick_task_assignments (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    quick_task_id UUID NOT NULL,
    assigned_to_user_id UUID NOT NULL,
    status CHARACTER VARYING(50) NULL DEFAULT 'pending'::character varying,
    accepted_at TIMESTAMP WITH TIME ZONE NULL,
    started_at TIMESTAMP WITH TIME ZONE NULL,
    completed_at TIMESTAMP WITH TIME ZONE NULL,
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    require_task_finished BOOLEAN NULL DEFAULT true,
    require_photo_upload BOOLEAN NULL DEFAULT false,
    require_erp_reference BOOLEAN NULL DEFAULT false,
    
    CONSTRAINT quick_task_assignments_pkey PRIMARY KEY (id),
    CONSTRAINT quick_task_assignments_quick_task_id_assigned_to_user_id_key 
        UNIQUE (quick_task_id, assigned_to_user_id),
    CONSTRAINT quick_task_assignments_assigned_to_user_id_fkey 
        FOREIGN KEY (assigned_to_user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT quick_task_assignments_quick_task_id_fkey 
        FOREIGN KEY (quick_task_id) REFERENCES quick_tasks (id) ON DELETE CASCADE,
    CONSTRAINT chk_require_task_finished_not_null 
        CHECK (require_task_finished IS NOT NULL)
) TABLESPACE pg_default;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_task 
ON public.quick_task_assignments USING btree (quick_task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_user 
ON public.quick_task_assignments USING btree (assigned_to_user_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_status 
ON public.quick_task_assignments USING btree (status) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_created_at 
ON public.quick_task_assignments USING btree (created_at) 
TABLESPACE pg_default;

-- Create indexes for completion requirements
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_require_task_finished
ON public.quick_task_assignments USING btree (require_task_finished)
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_require_photo_upload
ON public.quick_task_assignments USING btree (require_photo_upload) 
WHERE require_photo_upload = true
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_require_erp_reference
ON public.quick_task_assignments USING btree (require_erp_reference) 
WHERE require_erp_reference = true
TABLESPACE pg_default;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_accepted_at 
ON public.quick_task_assignments (accepted_at) 
WHERE accepted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_started_at 
ON public.quick_task_assignments (started_at) 
WHERE started_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_completed_at 
ON public.quick_task_assignments (completed_at) 
WHERE completed_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_updated_at 
ON public.quick_task_assignments (updated_at DESC);

-- Create composite indexes for common queries
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_user_status 
ON public.quick_task_assignments (assigned_to_user_id, status);

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_task_status 
ON public.quick_task_assignments (quick_task_id, status);

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_pending 
ON public.quick_task_assignments (assigned_to_user_id, created_at DESC) 
WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_active 
ON public.quick_task_assignments (assigned_to_user_id, started_at DESC) 
WHERE status IN ('accepted', 'in_progress');

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_quick_task_assignments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    
    -- Auto-set timestamps based on status changes
    IF NEW.status = 'accepted' AND OLD.status = 'pending' AND NEW.accepted_at IS NULL THEN
        NEW.accepted_at = now();
    END IF;
    
    IF NEW.status = 'in_progress' AND OLD.status != 'in_progress' AND NEW.started_at IS NULL THEN
        NEW.started_at = now();
    END IF;
    
    IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.completed_at IS NULL THEN
        NEW.completed_at = now();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_quick_task_assignments_updated_at 
BEFORE UPDATE ON quick_task_assignments 
FOR EACH ROW 
EXECUTE FUNCTION update_quick_task_assignments_updated_at();

-- Add data validation constraints
ALTER TABLE public.quick_task_assignments 
ADD CONSTRAINT chk_status_valid 
CHECK (status IN (
    'pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'rejected'
));

ALTER TABLE public.quick_task_assignments 
ADD CONSTRAINT chk_accepted_at_when_accepted 
CHECK (
    (status = 'pending' AND accepted_at IS NULL) OR
    (status != 'pending' AND accepted_at IS NOT NULL)
);

ALTER TABLE public.quick_task_assignments 
ADD CONSTRAINT chk_started_at_when_started 
CHECK (
    (status NOT IN ('in_progress', 'completed') AND started_at IS NULL) OR
    (status IN ('in_progress', 'completed') AND started_at IS NOT NULL)
);

ALTER TABLE public.quick_task_assignments 
ADD CONSTRAINT chk_completed_at_when_completed 
CHECK (
    (status != 'completed' AND completed_at IS NULL) OR
    (status = 'completed' AND completed_at IS NOT NULL)
);

ALTER TABLE public.quick_task_assignments 
ADD CONSTRAINT chk_timestamp_sequence 
CHECK (
    (accepted_at IS NULL OR accepted_at >= created_at) AND
    (started_at IS NULL OR started_at >= COALESCE(accepted_at, created_at)) AND
    (completed_at IS NULL OR completed_at >= COALESCE(started_at, accepted_at, created_at))
);

-- Add table and column comments
COMMENT ON TABLE public.quick_task_assignments IS 'Assignments of quick tasks to specific users with status tracking';
COMMENT ON COLUMN public.quick_task_assignments.id IS 'Unique identifier for the assignment';
COMMENT ON COLUMN public.quick_task_assignments.quick_task_id IS 'Reference to the quick task being assigned';
COMMENT ON COLUMN public.quick_task_assignments.assigned_to_user_id IS 'User assigned to complete the task';
COMMENT ON COLUMN public.quick_task_assignments.status IS 'Current status of the assignment';
COMMENT ON COLUMN public.quick_task_assignments.accepted_at IS 'When the user accepted the assignment';
COMMENT ON COLUMN public.quick_task_assignments.started_at IS 'When the user started working on the task';
COMMENT ON COLUMN public.quick_task_assignments.completed_at IS 'When the task was completed';
COMMENT ON COLUMN public.quick_task_assignments.created_at IS 'When the assignment was created';
COMMENT ON COLUMN public.quick_task_assignments.updated_at IS 'When the assignment was last updated';
COMMENT ON COLUMN public.quick_task_assignments.require_task_finished IS 'Whether the task must be marked as finished for completion (always required)';
COMMENT ON COLUMN public.quick_task_assignments.require_photo_upload IS 'Whether a photo must be uploaded for task completion';
COMMENT ON COLUMN public.quick_task_assignments.require_erp_reference IS 'Whether an ERP reference number is required for task completion';

-- Create trigger functions
CREATE OR REPLACE FUNCTION create_quick_task_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Create notification for new quick task assignment
    INSERT INTO notifications (
        title,
        message,
        type,
        priority,
        target_type,
        target_users,
        task_assignment_id,
        created_by,
        created_by_name
    ) VALUES (
        'New Quick Task Assigned',
        'You have been assigned a new quick task. Please check your dashboard for details.',
        'task',
        'medium',
        'specific_users',
        jsonb_build_array(NEW.assigned_to_user_id::text),
        NEW.id,
        'system',
        'System'
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_quick_task_status()
RETURNS TRIGGER AS $$
DECLARE
    task_title VARCHAR;
    notification_message TEXT;
BEGIN
    -- Get task title for notification
    SELECT title INTO task_title 
    FROM quick_tasks 
    WHERE id = NEW.quick_task_id;
    
    -- Create status update notifications
    IF OLD.status != NEW.status THEN
        CASE NEW.status
            WHEN 'accepted' THEN
                notification_message := 'Task "' || COALESCE(task_title, 'Quick Task') || '" has been accepted.';
            WHEN 'in_progress' THEN
                notification_message := 'Work has started on task "' || COALESCE(task_title, 'Quick Task') || '".';
            WHEN 'completed' THEN
                notification_message := 'Task "' || COALESCE(task_title, 'Quick Task') || '" has been completed.';
            WHEN 'rejected' THEN
                notification_message := 'Task "' || COALESCE(task_title, 'Quick Task') || '" has been rejected.';
            WHEN 'cancelled' THEN
                notification_message := 'Task "' || COALESCE(task_title, 'Quick Task') || '" has been cancelled.';
            ELSE
                notification_message := NULL;
        END CASE;
        
        -- Insert notification if message was set
        IF notification_message IS NOT NULL THEN
            INSERT INTO notifications (
                title,
                message,
                type,
                priority,
                target_type,
                target_users,
                task_assignment_id,
                created_by,
                created_by_name
            ) VALUES (
                'Task Status Update',
                notification_message,
                'task',
                'low',
                'specific_users',
                jsonb_build_array(NEW.assigned_to_user_id::text),
                NEW.id,
                'system',
                'System'
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the triggers
CREATE TRIGGER trigger_create_quick_task_notification
AFTER INSERT ON quick_task_assignments 
FOR EACH ROW 
EXECUTE FUNCTION create_quick_task_notification();

CREATE TRIGGER trigger_update_quick_task_status
AFTER UPDATE ON quick_task_assignments 
FOR EACH ROW 
EXECUTE FUNCTION update_quick_task_status();

-- Create trigger to automatically copy requirements when assignment is created
CREATE TRIGGER trigger_copy_completion_requirements
AFTER INSERT ON quick_task_assignments
FOR EACH ROW
EXECUTE FUNCTION copy_completion_requirements_to_assignment();

-- Create view for assignment details with task and user info
CREATE OR REPLACE VIEW quick_task_assignment_details AS
SELECT 
    qta.id,
    qta.quick_task_id,
    qt.title as task_title,
    qt.description as task_description,
    qt.priority as task_priority,
    qt.deadline_datetime as task_due_date,
    qta.assigned_to_user_id,
    u.username,
    u.full_name,
    qta.status,
    qta.require_task_finished,
    qta.require_photo_upload,
    qta.require_erp_reference,
    qta.accepted_at,
    qta.started_at,
    qta.completed_at,
    qta.created_at,
    qta.updated_at,
    CASE 
        WHEN qta.completed_at IS NOT NULL AND qta.started_at IS NOT NULL 
        THEN qta.completed_at - qta.started_at
        ELSE NULL
    END as completion_duration,
    CASE 
        WHEN qt.deadline_datetime IS NOT NULL AND qta.completed_at IS NOT NULL 
        THEN qta.completed_at <= qt.deadline_datetime
        ELSE NULL
    END as completed_on_time
FROM quick_task_assignments qta
JOIN quick_tasks qt ON qta.quick_task_id = qt.id
JOIN users u ON qta.assigned_to_user_id = u.id
ORDER BY qta.created_at DESC;

-- Create function to get user assignments
CREATE OR REPLACE FUNCTION get_user_quick_task_assignments(
    user_id_param UUID,
    status_filter VARCHAR DEFAULT NULL,
    limit_count INTEGER DEFAULT 50
)
RETURNS TABLE(
    assignment_id UUID,
    task_id UUID,
    task_title VARCHAR,
    task_description TEXT,
    task_priority VARCHAR,
    task_due_date TIMESTAMPTZ,
    status VARCHAR,
    require_task_finished BOOLEAN,
    require_photo_upload BOOLEAN,
    require_erp_reference BOOLEAN,
    accepted_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        qta.id,
        qta.quick_task_id,
        qt.title,
        qt.description,
        qt.priority,
        qt.deadline_datetime,
        qta.status,
        qta.require_task_finished,
        qta.require_photo_upload,
        qta.require_erp_reference,
        qta.accepted_at,
        qta.started_at,
        qta.completed_at,
        qta.created_at
    FROM quick_task_assignments qta
    JOIN quick_tasks qt ON qta.quick_task_id = qt.id
    WHERE qta.assigned_to_user_id = user_id_param
      AND (status_filter IS NULL OR qta.status = status_filter)
    ORDER BY qta.created_at DESC
    LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to update assignment status
CREATE OR REPLACE FUNCTION update_assignment_status(
    assignment_id UUID,
    new_status VARCHAR
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE quick_task_assignments 
    SET status = new_status,
        updated_at = now()
    WHERE id = assignment_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get assignment statistics
CREATE OR REPLACE FUNCTION get_quick_task_assignment_stats()
RETURNS TABLE(
    total_assignments BIGINT,
    pending_count BIGINT,
    accepted_count BIGINT,
    in_progress_count BIGINT,
    completed_count BIGINT,
    cancelled_count BIGINT,
    rejected_count BIGINT,
    require_photo_count BIGINT,
    require_erp_count BIGINT,
    avg_acceptance_time INTERVAL,
    avg_completion_time INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_assignments,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
        COUNT(*) FILTER (WHERE status = 'accepted') as accepted_count,
        COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_count,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
        COUNT(*) FILTER (WHERE status = 'cancelled') as cancelled_count,
        COUNT(*) FILTER (WHERE status = 'rejected') as rejected_count,
        COUNT(*) FILTER (WHERE require_photo_upload = true) as require_photo_count,
        COUNT(*) FILTER (WHERE require_erp_reference = true) as require_erp_count,
        AVG(accepted_at - created_at) FILTER (WHERE accepted_at IS NOT NULL) as avg_acceptance_time,
        AVG(completed_at - started_at) FILTER (WHERE completed_at IS NOT NULL AND started_at IS NOT NULL) as avg_completion_time
    FROM quick_task_assignments;
END;
$$ LANGUAGE plpgsql;

-- Create function to create assignments with completion requirements
CREATE OR REPLACE FUNCTION create_quick_task_assignment(
    quick_task_id_param UUID,
    assigned_to_user_id_param UUID,
    require_task_finished_param BOOLEAN DEFAULT true,
    require_photo_upload_param BOOLEAN DEFAULT false,
    require_erp_reference_param BOOLEAN DEFAULT false
)
RETURNS UUID AS $$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO quick_task_assignments (
        quick_task_id,
        assigned_to_user_id,
        require_task_finished,
        require_photo_upload,
        require_erp_reference,
        status
    ) VALUES (
        quick_task_id_param,
        assigned_to_user_id_param,
        require_task_finished_param,
        require_photo_upload_param,
        require_erp_reference_param,
        'pending'
    ) RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$ LANGUAGE plpgsql;

-- Create trigger function to copy completion requirements from task to assignment
CREATE OR REPLACE FUNCTION copy_completion_requirements_to_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- Update the assignment with completion requirements from the task
    UPDATE quick_task_assignments 
    SET 
        require_task_finished = (
            SELECT require_task_finished 
            FROM quick_tasks 
            WHERE id = NEW.quick_task_id
        ),
        require_photo_upload = (
            SELECT require_photo_upload 
            FROM quick_tasks 
            WHERE id = NEW.quick_task_id
        ),
        require_erp_reference = (
            SELECT require_erp_reference 
            FROM quick_tasks 
            WHERE id = NEW.quick_task_id
        )
    WHERE id = NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;