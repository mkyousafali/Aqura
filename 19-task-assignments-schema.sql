-- =====================================================
-- Table: task_assignments
-- Description: Task assignment management system
-- This table manages task assignments to users and branches with status tracking
-- =====================================================

-- Create enum types for task assignments
CREATE TYPE public.task_assignment_type_enum AS ENUM (
    'individual',
    'branch',
    'department',
    'role_based',
    'collaborative'
);

CREATE TYPE public.task_assignment_status_enum AS ENUM (
    'assigned',
    'accepted',
    'in_progress',
    'completed',
    'rejected',
    'cancelled',
    'overdue',
    'pending_review'
);

-- Create task_assignments table
CREATE TABLE public.task_assignments (
    -- Primary key with UUID generation
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    
    -- Foreign key to tasks table
    task_id UUID NOT NULL,
    
    -- Assignment configuration
    assignment_type TEXT NOT NULL,
    assigned_to_user_id TEXT NULL,
    assigned_to_branch_id UUID NULL,
    
    -- Assignment metadata
    assigned_by TEXT NOT NULL,
    assigned_by_name TEXT NULL,
    assigned_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    -- Status tracking
    status TEXT NULL DEFAULT 'assigned'::text,
    started_at TIMESTAMP WITH TIME ZONE NULL,
    completed_at TIMESTAMP WITH TIME ZONE NULL,
    
    -- Primary key constraint
    CONSTRAINT task_assignments_pkey PRIMARY KEY (id),
    
    -- Unique constraint to prevent duplicate assignments
    CONSTRAINT task_assignments_task_id_assignment_type_assigned_to_user_i_key 
        UNIQUE (task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id),
    
    -- Foreign key to tasks table with CASCADE delete
    CONSTRAINT task_assignments_task_id_fkey 
        FOREIGN KEY (task_id) 
        REFERENCES tasks (id) 
        ON DELETE CASCADE,
    
    -- Check constraints for data integrity
    CONSTRAINT chk_assignment_target_required 
        CHECK (
            (assignment_type = 'individual' AND assigned_to_user_id IS NOT NULL) OR
            (assignment_type = 'branch' AND assigned_to_branch_id IS NOT NULL) OR
            (assignment_type = 'department' AND assigned_to_branch_id IS NOT NULL) OR
            (assignment_type = 'role_based' AND assigned_to_user_id IS NOT NULL) OR
            (assignment_type = 'collaborative' AND (assigned_to_user_id IS NOT NULL OR assigned_to_branch_id IS NOT NULL))
        ),
    
    -- Check constraint for valid assignment types
    CONSTRAINT chk_assignment_type_valid 
        CHECK (assignment_type IN ('individual', 'branch', 'department', 'role_based', 'collaborative')),
    
    -- Check constraint for valid status values
    CONSTRAINT chk_assignment_status_valid 
        CHECK (status IN ('assigned', 'accepted', 'in_progress', 'completed', 'rejected', 'cancelled', 'overdue', 'pending_review')),
    
    -- Check constraint for logical timestamp progression
    CONSTRAINT chk_assignment_timestamps_logical 
        CHECK (
            (started_at IS NULL OR started_at >= assigned_at) AND
            (completed_at IS NULL OR (started_at IS NOT NULL AND completed_at >= started_at))
        )
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Primary lookup indexes
CREATE INDEX IF NOT EXISTS idx_task_assignments_task_id 
    ON public.task_assignments 
    USING btree (task_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_user_id 
    ON public.task_assignments 
    USING btree (assigned_to_user_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_to_branch_id 
    ON public.task_assignments 
    USING btree (assigned_to_branch_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assignment_type 
    ON public.task_assignments 
    USING btree (assignment_type) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_status 
    ON public.task_assignments 
    USING btree (status) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_by 
    ON public.task_assignments 
    USING btree (assigned_by) 
    TABLESPACE pg_default;

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_task_assignments_user_status 
    ON public.task_assignments 
    USING btree (assigned_to_user_id, status, assigned_at DESC) 
    TABLESPACE pg_default
    WHERE assigned_to_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_assignments_branch_status 
    ON public.task_assignments 
    USING btree (assigned_to_branch_id, status, assigned_at DESC) 
    TABLESPACE pg_default
    WHERE assigned_to_branch_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_assignments_type_status 
    ON public.task_assignments 
    USING btree (assignment_type, status, assigned_at DESC) 
    TABLESPACE pg_default;

-- Temporal indexes
CREATE INDEX IF NOT EXISTS idx_task_assignments_assigned_at 
    ON public.task_assignments 
    USING btree (assigned_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_assignments_started_at 
    ON public.task_assignments 
    USING btree (started_at DESC) 
    TABLESPACE pg_default
    WHERE started_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_assignments_completed_at 
    ON public.task_assignments 
    USING btree (completed_at DESC) 
    TABLESPACE pg_default
    WHERE completed_at IS NOT NULL;

-- Active assignments index (excluding completed/cancelled)
CREATE INDEX IF NOT EXISTS idx_task_assignments_active 
    ON public.task_assignments 
    USING btree (assigned_to_user_id, status, assigned_at DESC) 
    TABLESPACE pg_default
    WHERE status NOT IN ('completed', 'cancelled', 'rejected');

-- Overdue assignments tracking index
CREATE INDEX IF NOT EXISTS idx_task_assignments_overdue 
    ON public.task_assignments 
    USING btree (assigned_at, status) 
    TABLESPACE pg_default
    WHERE status = 'overdue';

-- =====================================================
-- Triggers for Automatic Updates
-- =====================================================

-- Create trigger function for assignment status management
CREATE OR REPLACE FUNCTION update_task_assignment_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-set started_at when status changes to in_progress
    IF NEW.status = 'in_progress' AND OLD.status != 'in_progress' AND NEW.started_at IS NULL THEN
        NEW.started_at = now();
    END IF;
    
    -- Auto-set completed_at when status changes to completed
    IF NEW.status = 'completed' AND OLD.status != 'completed' AND NEW.completed_at IS NULL THEN
        NEW.completed_at = now();
    END IF;
    
    -- Clear started_at and completed_at if status reverts to assigned
    IF NEW.status = 'assigned' AND OLD.status != 'assigned' THEN
        NEW.started_at = NULL;
        NEW.completed_at = NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic status timestamp management
CREATE TRIGGER trigger_task_assignment_status_timestamps
    BEFORE UPDATE ON public.task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_task_assignment_status();

-- =====================================================
-- Functions for Assignment Management
-- =====================================================

-- Function to assign task to user
CREATE OR REPLACE FUNCTION assign_task_to_user(
    p_task_id UUID,
    p_user_id TEXT,
    p_assigned_by TEXT,
    p_assigned_by_name TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO public.task_assignments (
        task_id, assignment_type, assigned_to_user_id, assigned_by, assigned_by_name
    ) VALUES (
        p_task_id, 'individual', p_user_id, p_assigned_by, p_assigned_by_name
    )
    ON CONFLICT (task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id) 
    DO UPDATE SET
        assigned_by = EXCLUDED.assigned_by,
        assigned_by_name = EXCLUDED.assigned_by_name,
        assigned_at = now(),
        status = 'assigned'
    RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$ LANGUAGE plpgsql;

-- Function to assign task to branch
CREATE OR REPLACE FUNCTION assign_task_to_branch(
    p_task_id UUID,
    p_branch_id UUID,
    p_assigned_by TEXT,
    p_assigned_by_name TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO public.task_assignments (
        task_id, assignment_type, assigned_to_branch_id, assigned_by, assigned_by_name
    ) VALUES (
        p_task_id, 'branch', p_branch_id, p_assigned_by, p_assigned_by_name
    )
    ON CONFLICT (task_id, assignment_type, assigned_to_user_id, assigned_to_branch_id) 
    DO UPDATE SET
        assigned_by = EXCLUDED.assigned_by,
        assigned_by_name = EXCLUDED.assigned_by_name,
        assigned_at = now(),
        status = 'assigned'
    RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update assignment status
CREATE OR REPLACE FUNCTION update_assignment_status(
    p_assignment_id UUID,
    p_new_status TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.task_assignments 
    SET status = p_new_status
    WHERE id = p_assignment_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to get user assignments
CREATE OR REPLACE FUNCTION get_user_assignments(
    p_user_id TEXT,
    p_status_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
    assignment_id UUID,
    task_id UUID,
    task_title VARCHAR,
    assignment_type TEXT,
    status TEXT,
    assigned_at TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ta.id as assignment_id,
        ta.task_id,
        t.title::VARCHAR as task_title,
        ta.assignment_type,
        ta.status,
        ta.assigned_at,
        ta.started_at,
        ta.completed_at
    FROM public.task_assignments ta
    JOIN public.tasks t ON ta.task_id = t.id
    WHERE ta.assigned_to_user_id = p_user_id
      AND (p_status_filter IS NULL OR ta.status = p_status_filter)
    ORDER BY ta.assigned_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get branch assignments
CREATE OR REPLACE FUNCTION get_branch_assignments(
    p_branch_id UUID,
    p_status_filter TEXT DEFAULT NULL
)
RETURNS TABLE (
    assignment_id UUID,
    task_id UUID,
    task_title VARCHAR,
    assignment_type TEXT,
    status TEXT,
    assigned_at TIMESTAMP WITH TIME ZONE,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ta.id as assignment_id,
        ta.task_id,
        t.title::VARCHAR as task_title,
        ta.assignment_type,
        ta.status,
        ta.assigned_at,
        ta.started_at,
        ta.completed_at
    FROM public.task_assignments ta
    JOIN public.tasks t ON ta.task_id = t.id
    WHERE ta.assigned_to_branch_id = p_branch_id
      AND (p_status_filter IS NULL OR ta.status = p_status_filter)
    ORDER BY ta.assigned_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to reassign task
CREATE OR REPLACE FUNCTION reassign_task(
    p_assignment_id UUID,
    p_new_user_id TEXT DEFAULT NULL,
    p_new_branch_id UUID DEFAULT NULL,
    p_reassigned_by TEXT DEFAULT 'system'
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.task_assignments 
    SET assigned_to_user_id = p_new_user_id,
        assigned_to_branch_id = p_new_branch_id,
        assigned_by = p_reassigned_by,
        assigned_at = now(),
        status = 'assigned',
        started_at = NULL,
        completed_at = NULL
    WHERE id = p_assignment_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Views for Common Assignment Queries
-- =====================================================

-- View for active assignments summary
CREATE OR REPLACE VIEW active_task_assignments AS
SELECT 
    ta.id,
    ta.task_id,
    t.title as task_title,
    t.priority as task_priority,
    ta.assignment_type,
    ta.assigned_to_user_id,
    ta.assigned_to_branch_id,
    b.name_en as branch_name,
    ta.assigned_by,
    ta.assigned_by_name,
    ta.status,
    ta.assigned_at,
    ta.started_at,
    EXTRACT(EPOCH FROM (now() - ta.assigned_at))/3600 as hours_since_assigned
FROM public.task_assignments ta
JOIN public.tasks t ON ta.task_id = t.id
LEFT JOIN public.branches b ON ta.assigned_to_branch_id = b.id
WHERE ta.status NOT IN ('completed', 'cancelled', 'rejected')
ORDER BY ta.assigned_at DESC;

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.task_assignments IS 'Task assignment management system tracking assignments to users and branches with status progression';

COMMENT ON COLUMN public.task_assignments.id IS 'Primary key - unique identifier for each task assignment';
COMMENT ON COLUMN public.task_assignments.task_id IS 'Foreign key to tasks table - which task is being assigned';
COMMENT ON COLUMN public.task_assignments.assignment_type IS 'Type of assignment (individual, branch, department, role_based, collaborative)';
COMMENT ON COLUMN public.task_assignments.assigned_to_user_id IS 'User ID for individual assignments';
COMMENT ON COLUMN public.task_assignments.assigned_to_branch_id IS 'Branch ID for branch/department assignments';
COMMENT ON COLUMN public.task_assignments.assigned_by IS 'User ID of the person who made the assignment';
COMMENT ON COLUMN public.task_assignments.assigned_by_name IS 'Display name of the person who made the assignment';
COMMENT ON COLUMN public.task_assignments.assigned_at IS 'Timestamp when the assignment was created';
COMMENT ON COLUMN public.task_assignments.status IS 'Current status of the assignment (assigned, in_progress, completed, etc.)';
COMMENT ON COLUMN public.task_assignments.started_at IS 'Timestamp when work on the assignment was started';
COMMENT ON COLUMN public.task_assignments.completed_at IS 'Timestamp when the assignment was completed';

-- Index comments
COMMENT ON INDEX idx_task_assignments_task_id IS 'Performance index for task-based assignment queries';
COMMENT ON INDEX idx_task_assignments_user_status IS 'Composite index for user assignment dashboard queries';
COMMENT ON INDEX idx_task_assignments_active IS 'Partial index for active (non-completed) assignments';
COMMENT ON INDEX idx_task_assignments_overdue IS 'Partial index for overdue assignment tracking';

-- Function comments
COMMENT ON FUNCTION assign_task_to_user(UUID, TEXT, TEXT, TEXT) IS 'Assigns a task to a specific user with upsert logic';
COMMENT ON FUNCTION assign_task_to_branch(UUID, UUID, TEXT, TEXT) IS 'Assigns a task to a branch with upsert logic';
COMMENT ON FUNCTION get_user_assignments(TEXT, TEXT) IS 'Returns all assignments for a specific user with optional status filtering';
COMMENT ON FUNCTION reassign_task(UUID, TEXT, UUID, TEXT) IS 'Reassigns a task to a different user or branch';

-- View comments
COMMENT ON VIEW active_task_assignments IS 'Comprehensive view of all active task assignments with task and branch details';