-- =====================================================
-- Enhanced Task Assignments Schema
-- Description: Adds scheduling, deadline, and reassignment capabilities
-- This script enhances the existing task_assignments table with new columns
-- =====================================================

-- Add new columns to the existing task_assignments table
ALTER TABLE public.task_assignments 
ADD COLUMN IF NOT EXISTS schedule_date DATE,
ADD COLUMN IF NOT EXISTS schedule_time TIME,
ADD COLUMN IF NOT EXISTS deadline_date DATE,
ADD COLUMN IF NOT EXISTS deadline_time TIME,
ADD COLUMN IF NOT EXISTS deadline_datetime TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS is_reassignable BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS recurring_pattern JSONB DEFAULT NULL,
ADD COLUMN IF NOT EXISTS notes TEXT,
ADD COLUMN IF NOT EXISTS priority_override TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS require_task_finished BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS require_photo_upload BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS require_erp_reference BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS reassigned_from UUID DEFAULT NULL,
ADD COLUMN IF NOT EXISTS reassignment_reason TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS reassigned_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;

-- Create function to update deadline_datetime
CREATE OR REPLACE FUNCTION update_deadline_datetime()
RETURNS TRIGGER AS $$
BEGIN
    NEW.deadline_datetime := CASE 
        WHEN NEW.deadline_date IS NOT NULL AND NEW.deadline_time IS NOT NULL THEN 
            (NEW.deadline_date::text || ' ' || NEW.deadline_time::text)::timestamp with time zone
        WHEN NEW.deadline_date IS NOT NULL THEN 
            NEW.deadline_date::timestamp with time zone
        ELSE NULL
    END;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update deadline_datetime
DROP TRIGGER IF EXISTS trigger_update_deadline_datetime ON public.task_assignments;
CREATE TRIGGER trigger_update_deadline_datetime
    BEFORE INSERT OR UPDATE OF deadline_date, deadline_time ON public.task_assignments
    FOR EACH ROW
    EXECUTE FUNCTION update_deadline_datetime();

-- Add foreign key constraint for reassignment tracking
ALTER TABLE public.task_assignments 
ADD CONSTRAINT fk_task_assignments_reassigned_from 
FOREIGN KEY (reassigned_from) REFERENCES public.task_assignments(id) ON DELETE SET NULL;

-- Add check constraints for the new columns
ALTER TABLE public.task_assignments 
ADD CONSTRAINT chk_deadline_consistency 
CHECK (
    (deadline_date IS NULL AND deadline_time IS NULL) OR 
    (deadline_date IS NOT NULL)
);

ALTER TABLE public.task_assignments 
ADD CONSTRAINT chk_schedule_consistency 
CHECK (
    (schedule_date IS NULL AND schedule_time IS NULL) OR 
    (schedule_date IS NOT NULL)
);

ALTER TABLE public.task_assignments 
ADD CONSTRAINT chk_priority_override_valid 
CHECK (priority_override IS NULL OR priority_override IN ('low', 'medium', 'high', 'urgent'));

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_task_assignments_deadline_datetime 
    ON public.task_assignments 
    USING btree (deadline_datetime) 
    WHERE deadline_datetime IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_assignments_schedule_date 
    ON public.task_assignments 
    USING btree (schedule_date) 
    WHERE schedule_date IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_assignments_recurring 
    ON public.task_assignments 
    USING btree (is_recurring, status) 
    WHERE is_recurring = true;

CREATE INDEX IF NOT EXISTS idx_task_assignments_reassignable 
    ON public.task_assignments 
    USING btree (is_reassignable, status) 
    WHERE is_reassignable = true;

CREATE INDEX IF NOT EXISTS idx_task_assignments_overdue 
    ON public.task_assignments 
    USING btree (deadline_datetime, status) 
    WHERE deadline_datetime IS NOT NULL AND status NOT IN ('completed', 'cancelled');

-- =====================================================
-- Recurring Assignments Table
-- =====================================================

CREATE TABLE IF NOT EXISTS public.recurring_assignment_schedules (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL,
    
    -- Schedule configuration
    repeat_type TEXT NOT NULL CHECK (repeat_type IN ('daily', 'weekly', 'monthly', 'yearly', 'custom')),
    repeat_interval INTEGER NOT NULL DEFAULT 1,
    repeat_on_days INTEGER[] DEFAULT NULL, -- For weekly: [1,2,3,4,5] (Mon-Fri), For monthly: [1,15] (1st and 15th)
    repeat_on_date INTEGER DEFAULT NULL, -- For monthly: day of month (1-31)
    repeat_on_month INTEGER DEFAULT NULL, -- For yearly: month (1-12)
    
    -- Time settings
    execute_time TIME NOT NULL DEFAULT '09:00:00',
    timezone TEXT DEFAULT 'UTC',
    
    -- Schedule bounds
    start_date DATE NOT NULL,
    end_date DATE DEFAULT NULL,
    max_occurrences INTEGER DEFAULT NULL,
    
    -- Status and tracking
    is_active BOOLEAN DEFAULT true,
    last_executed_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    next_execution_at TIMESTAMP WITH TIME ZONE NOT NULL,
    executions_count INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    created_by TEXT NOT NULL,
    
    -- Constraints
    CONSTRAINT recurring_assignment_schedules_pkey PRIMARY KEY (id),
    CONSTRAINT fk_recurring_schedules_assignment 
        FOREIGN KEY (assignment_id) 
        REFERENCES public.task_assignments(id) 
        ON DELETE CASCADE,
    
    -- Check constraints
    CONSTRAINT chk_repeat_interval_positive 
        CHECK (repeat_interval > 0),
    CONSTRAINT chk_max_occurrences_positive 
        CHECK (max_occurrences IS NULL OR max_occurrences > 0),
    CONSTRAINT chk_schedule_bounds 
        CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_next_execution_after_start 
        CHECK (next_execution_at::date >= start_date)
);

-- Indexes for recurring schedules
CREATE INDEX IF NOT EXISTS idx_recurring_schedules_assignment_id 
    ON public.recurring_assignment_schedules 
    USING btree (assignment_id);

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_next_execution 
    ON public.recurring_assignment_schedules 
    USING btree (next_execution_at, is_active) 
    WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_recurring_schedules_active 
    ON public.recurring_assignment_schedules 
    USING btree (is_active, repeat_type);

-- =====================================================
-- Enhanced Functions
-- =====================================================

-- Function to create assignment with scheduling
CREATE OR REPLACE FUNCTION create_scheduled_assignment(
    p_task_id UUID,
    p_assignment_type TEXT,
    p_assigned_by TEXT,
    p_assigned_to_user_id TEXT DEFAULT NULL,
    p_assigned_to_branch_id UUID DEFAULT NULL,
    p_assigned_by_name TEXT DEFAULT NULL,
    p_schedule_date DATE DEFAULT NULL,
    p_schedule_time TIME DEFAULT NULL,
    p_deadline_date DATE DEFAULT NULL,
    p_deadline_time TIME DEFAULT NULL,
    p_is_reassignable BOOLEAN DEFAULT true,
    p_notes TEXT DEFAULT NULL,
    p_priority_override TEXT DEFAULT NULL,
    p_require_task_finished BOOLEAN DEFAULT true,
    p_require_photo_upload BOOLEAN DEFAULT false,
    p_require_erp_reference BOOLEAN DEFAULT false
)
RETURNS UUID AS $$
DECLARE
    assignment_id UUID;
BEGIN
    INSERT INTO public.task_assignments (
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
        is_reassignable,
        notes,
        priority_override,
        require_task_finished,
        require_photo_upload,
        require_erp_reference
    ) VALUES (
        p_task_id,
        p_assignment_type,
        p_assigned_to_user_id,
        p_assigned_to_branch_id,
        p_assigned_by,
        p_assigned_by_name,
        p_schedule_date,
        p_schedule_time,
        p_deadline_date,
        p_deadline_time,
        p_is_reassignable,
        p_notes,
        p_priority_override,
        p_require_task_finished,
        p_require_photo_upload,
        p_require_erp_reference
    )
    RETURNING id INTO assignment_id;
    
    RETURN assignment_id;
END;
$$ LANGUAGE plpgsql;

-- Function to create recurring assignment
CREATE OR REPLACE FUNCTION create_recurring_assignment(
    p_task_id UUID,
    p_assignment_type TEXT,
    p_assigned_by TEXT,
    p_repeat_type TEXT,
    p_assigned_to_user_id TEXT DEFAULT NULL,
    p_assigned_to_branch_id UUID DEFAULT NULL,
    p_assigned_by_name TEXT DEFAULT NULL,
    p_repeat_interval INTEGER DEFAULT 1,
    p_repeat_on_days INTEGER[] DEFAULT NULL,
    p_execute_time TIME DEFAULT '09:00:00',
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT NULL,
    p_max_occurrences INTEGER DEFAULT NULL,
    p_notes TEXT DEFAULT NULL,
    p_is_reassignable BOOLEAN DEFAULT true
)
RETURNS UUID AS $$
DECLARE
    assignment_id UUID;
    next_exec_time TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Calculate first execution time
    next_exec_time := (p_start_date::text || ' ' || p_execute_time::text)::timestamp with time zone;
    
    -- Create the assignment record
    INSERT INTO public.task_assignments (
        task_id,
        assignment_type,
        assigned_to_user_id,
        assigned_to_branch_id,
        assigned_by,
        assigned_by_name,
        is_recurring,
        is_reassignable,
        notes
    ) VALUES (
        p_task_id,
        p_assignment_type,
        p_assigned_to_user_id,
        p_assigned_to_branch_id,
        p_assigned_by,
        p_assigned_by_name,
        true,
        p_is_reassignable,
        p_notes
    )
    RETURNING id INTO assignment_id;
    
    -- Create the recurring schedule
    INSERT INTO public.recurring_assignment_schedules (
        assignment_id,
        repeat_type,
        repeat_interval,
        repeat_on_days,
        execute_time,
        start_date,
        end_date,
        max_occurrences,
        next_execution_at,
        created_by
    ) VALUES (
        assignment_id,
        p_repeat_type,
        p_repeat_interval,
        p_repeat_on_days,
        p_execute_time,
        p_start_date,
        p_end_date,
        p_max_occurrences,
        next_exec_time,
        p_assigned_by
    );
    
    RETURN assignment_id;
END;
$$ LANGUAGE plpgsql;

-- Function to reassign task
CREATE OR REPLACE FUNCTION reassign_task(
    p_assignment_id UUID,
    p_reassigned_by TEXT,
    p_new_user_id TEXT DEFAULT NULL,
    p_new_branch_id UUID DEFAULT NULL,
    p_reassignment_reason TEXT DEFAULT NULL,
    p_copy_deadline BOOLEAN DEFAULT true
)
RETURNS UUID AS $$
DECLARE
    new_assignment_id UUID;
    original_assignment RECORD;
BEGIN
    -- Get original assignment details
    SELECT * INTO original_assignment 
    FROM public.task_assignments 
    WHERE id = p_assignment_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Assignment not found: %', p_assignment_id;
    END IF;
    
    IF NOT original_assignment.is_reassignable THEN
        RAISE EXCEPTION 'Assignment is not reassignable: %', p_assignment_id;
    END IF;
    
    -- Create new assignment
    INSERT INTO public.task_assignments (
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
        is_reassignable,
        notes,
        priority_override,
        require_task_finished,
        require_photo_upload,
        require_erp_reference,
        reassigned_from,
        reassignment_reason,
        reassigned_at
    ) VALUES (
        original_assignment.task_id,
        original_assignment.assignment_type,
        p_new_user_id,
        p_new_branch_id,
        p_reassigned_by,
        NULL, -- Will be filled by the application
        CASE WHEN p_copy_deadline THEN original_assignment.schedule_date ELSE NULL END,
        CASE WHEN p_copy_deadline THEN original_assignment.schedule_time ELSE NULL END,
        CASE WHEN p_copy_deadline THEN original_assignment.deadline_date ELSE NULL END,
        CASE WHEN p_copy_deadline THEN original_assignment.deadline_time ELSE NULL END,
        original_assignment.is_reassignable,
        original_assignment.notes,
        original_assignment.priority_override,
        original_assignment.require_task_finished,
        original_assignment.require_photo_upload,
        original_assignment.require_erp_reference,
        p_assignment_id,
        p_reassignment_reason,
        now()
    )
    RETURNING id INTO new_assignment_id;
    
    -- Mark original assignment as reassigned
    UPDATE public.task_assignments 
    SET status = 'reassigned',
        completed_at = now()
    WHERE id = p_assignment_id;
    
    RETURN new_assignment_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get assignments with deadline information
CREATE OR REPLACE FUNCTION get_assignments_with_deadlines(
    p_user_id TEXT DEFAULT NULL,
    p_branch_id UUID DEFAULT NULL,
    p_include_overdue BOOLEAN DEFAULT true,
    p_days_ahead INTEGER DEFAULT 7
)
RETURNS TABLE (
    assignment_id UUID,
    task_id UUID,
    task_title TEXT,
    task_description TEXT,
    task_priority TEXT,
    assignment_status TEXT,
    assigned_to_user_id TEXT,
    assigned_to_branch_id UUID,
    deadline_datetime TIMESTAMP WITH TIME ZONE,
    schedule_date DATE,
    schedule_time TIME,
    is_overdue BOOLEAN,
    hours_until_deadline NUMERIC,
    is_reassignable BOOLEAN,
    notes TEXT,
    require_task_finished BOOLEAN,
    require_photo_upload BOOLEAN,
    require_erp_reference BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ta.id as assignment_id,
        t.id as task_id,
        t.title as task_title,
        t.description as task_description,
        COALESCE(ta.priority_override, t.priority) as task_priority,
        ta.status as assignment_status,
        ta.assigned_to_user_id,
        ta.assigned_to_branch_id,
        ta.deadline_datetime,
        ta.schedule_date,
        ta.schedule_time,
        CASE 
            WHEN ta.deadline_datetime IS NOT NULL AND ta.deadline_datetime < now() 
                AND ta.status NOT IN ('completed', 'cancelled') 
            THEN true 
            ELSE false 
        END as is_overdue,
        CASE 
            WHEN ta.deadline_datetime IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (ta.deadline_datetime - now()))/3600 
            ELSE NULL 
        END as hours_until_deadline,
        ta.is_reassignable,
        ta.notes,
        ta.require_task_finished,
        ta.require_photo_upload,
        ta.require_erp_reference
    FROM public.task_assignments ta
    JOIN public.tasks t ON ta.task_id = t.id
    WHERE 
        (p_user_id IS NULL OR ta.assigned_to_user_id = p_user_id) AND
        (p_branch_id IS NULL OR ta.assigned_to_branch_id = p_branch_id) AND
        ta.status NOT IN ('cancelled', 'reassigned') AND
        (
            p_include_overdue = true OR 
            ta.deadline_datetime IS NULL OR 
            ta.deadline_datetime >= now()
        ) AND
        (
            ta.deadline_datetime IS NULL OR 
            ta.deadline_datetime <= now() + (p_days_ahead || ' days')::interval
        )
    ORDER BY 
        CASE WHEN ta.deadline_datetime IS NOT NULL AND ta.deadline_datetime < now() THEN 1 ELSE 2 END,
        ta.deadline_datetime ASC NULLS LAST,
        ta.assigned_at DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Comments and Documentation
-- =====================================================

COMMENT ON COLUMN public.task_assignments.schedule_date IS 'The date when the task should be started/executed';
COMMENT ON COLUMN public.task_assignments.schedule_time IS 'The time when the task should be started/executed';
COMMENT ON COLUMN public.task_assignments.deadline_date IS 'The date when the task must be completed';
COMMENT ON COLUMN public.task_assignments.deadline_time IS 'The time when the task must be completed';
COMMENT ON COLUMN public.task_assignments.deadline_datetime IS 'Computed timestamp combining deadline_date and deadline_time';
COMMENT ON COLUMN public.task_assignments.is_reassignable IS 'Whether this assignment can be reassigned to another user';
COMMENT ON COLUMN public.task_assignments.is_recurring IS 'Whether this is a recurring assignment';
COMMENT ON COLUMN public.task_assignments.recurring_pattern IS 'JSON configuration for recurring patterns';
COMMENT ON COLUMN public.task_assignments.notes IS 'Additional instructions or notes for the assignee';
COMMENT ON COLUMN public.task_assignments.priority_override IS 'Override the task priority for this specific assignment';
COMMENT ON COLUMN public.task_assignments.require_task_finished IS 'Whether task completion confirmation is required';
COMMENT ON COLUMN public.task_assignments.require_photo_upload IS 'Whether photo upload is required for completion';
COMMENT ON COLUMN public.task_assignments.require_erp_reference IS 'Whether ERP reference is required for completion';
COMMENT ON COLUMN public.task_assignments.reassigned_from IS 'Reference to the original assignment if this is a reassignment';
COMMENT ON COLUMN public.task_assignments.reassignment_reason IS 'Reason for reassignment';

COMMENT ON TABLE public.recurring_assignment_schedules IS 'Configuration for recurring task assignments with flexible scheduling';
COMMENT ON FUNCTION create_scheduled_assignment IS 'Creates a one-time task assignment with optional scheduling and deadline';
COMMENT ON FUNCTION create_recurring_assignment IS 'Creates a recurring task assignment with schedule configuration';
COMMENT ON FUNCTION reassign_task IS 'Reassigns a task to a different user or branch while maintaining audit trail';
COMMENT ON FUNCTION get_assignments_with_deadlines IS 'Retrieves assignments with deadline information and overdue status';