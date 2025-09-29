-- =====================================================
-- Table: task_completions
-- Description: Task completion tracking and verification system
-- This table manages task completion records with multi-step verification process
-- =====================================================

-- Create enum types for task completions
CREATE TYPE public.task_completion_status_enum AS ENUM (
    'completed',
    'verified',
    'rejected',
    'pending_verification',
    'partially_completed'
);

-- Create task_completions table
CREATE TABLE public.task_completions (
    -- Primary key with UUID generation
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    
    -- Foreign keys to related tables
    task_id UUID NOT NULL,
    assignment_id UUID NOT NULL,
    
    -- Completion metadata
    completed_by TEXT NOT NULL,
    completed_by_name TEXT NULL,
    completed_by_branch_id UUID NULL,
    
    -- Multi-step completion tracking
    task_finished_completed BOOLEAN NULL DEFAULT false,
    photo_uploaded_completed BOOLEAN NULL DEFAULT false,
    erp_reference_completed BOOLEAN NULL DEFAULT false,
    erp_reference_number TEXT NULL,
    
    -- Completion details
    completion_notes TEXT NULL,
    
    -- Verification workflow
    verified_by TEXT NULL,
    verified_at TIMESTAMP WITH TIME ZONE NULL,
    verification_notes TEXT NULL,
    
    -- Audit timestamps
    completed_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    
    -- Primary key constraint
    CONSTRAINT task_completions_pkey PRIMARY KEY (id),
    
    -- Unique constraint to prevent duplicate completions per task-user
    CONSTRAINT task_completions_task_id_completed_by_key UNIQUE (task_id, completed_by),
    
    -- Foreign key to tasks table with CASCADE delete
    CONSTRAINT task_completions_task_id_fkey 
        FOREIGN KEY (task_id) 
        REFERENCES tasks (id) 
        ON DELETE CASCADE,
    
    -- Foreign key to task_assignments table with CASCADE delete
    CONSTRAINT task_completions_assignment_id_fkey 
        FOREIGN KEY (assignment_id) 
        REFERENCES task_assignments (id) 
        ON DELETE CASCADE,
    
    -- Check constraint for ERP reference consistency
    CONSTRAINT chk_erp_reference_consistency 
        CHECK (
            (erp_reference_completed = false OR erp_reference_number IS NOT NULL)
        ),
    
    -- Check constraint for verification consistency
    CONSTRAINT chk_verification_consistency 
        CHECK (
            (verified_by IS NULL AND verified_at IS NULL) OR
            (verified_by IS NOT NULL AND verified_at IS NOT NULL)
        ),
    
    -- Check constraint for logical timestamp order
    CONSTRAINT chk_completion_timestamps_logical 
        CHECK (
            (verified_at IS NULL OR verified_at >= completed_at) AND
            (completed_at >= created_at)
        )
) TABLESPACE pg_default;

-- =====================================================
-- Indexes for Performance Optimization
-- =====================================================

-- Primary lookup indexes
CREATE INDEX IF NOT EXISTS idx_task_completions_task_id 
    ON public.task_completions 
    USING btree (task_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_assignment_id 
    ON public.task_completions 
    USING btree (assignment_id) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_completed_by 
    ON public.task_completions 
    USING btree (completed_by) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_completed_by_branch_id 
    ON public.task_completions 
    USING btree (completed_by_branch_id) 
    TABLESPACE pg_default;

-- Completion step tracking indexes
CREATE INDEX IF NOT EXISTS idx_task_completions_task_finished 
    ON public.task_completions 
    USING btree (task_finished_completed) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_photo_uploaded 
    ON public.task_completions 
    USING btree (photo_uploaded_completed) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_erp_reference 
    ON public.task_completions 
    USING btree (erp_reference_completed) 
    TABLESPACE pg_default;

-- Temporal indexes
CREATE INDEX IF NOT EXISTS idx_task_completions_completed_at 
    ON public.task_completions 
    USING btree (completed_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_verified_at 
    ON public.task_completions 
    USING btree (verified_at DESC) 
    TABLESPACE pg_default
    WHERE verified_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_completions_created_at 
    ON public.task_completions 
    USING btree (created_at DESC) 
    TABLESPACE pg_default;

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_task_completions_user_timeline 
    ON public.task_completions 
    USING btree (completed_by, completed_at DESC) 
    TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_branch_timeline 
    ON public.task_completions 
    USING btree (completed_by_branch_id, completed_at DESC) 
    TABLESPACE pg_default
    WHERE completed_by_branch_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_completions_verification_status 
    ON public.task_completions 
    USING btree (verified_by, verified_at DESC) 
    TABLESPACE pg_default
    WHERE verified_by IS NOT NULL;

-- Multi-step completion progress index
CREATE INDEX IF NOT EXISTS idx_task_completions_progress 
    ON public.task_completions 
    USING btree (
        task_id, 
        task_finished_completed, 
        photo_uploaded_completed, 
        erp_reference_completed,
        completed_at DESC
    ) 
    TABLESPACE pg_default;

-- Pending verification index
CREATE INDEX IF NOT EXISTS idx_task_completions_pending_verification 
    ON public.task_completions 
    USING btree (completed_at DESC) 
    TABLESPACE pg_default
    WHERE verified_by IS NULL;

-- ERP reference lookup index
CREATE INDEX IF NOT EXISTS idx_task_completions_erp_reference_number 
    ON public.task_completions 
    USING btree (erp_reference_number) 
    TABLESPACE pg_default
    WHERE erp_reference_number IS NOT NULL;

-- =====================================================
-- Triggers for Automatic Updates
-- =====================================================

-- Create trigger function for completion status management
CREATE OR REPLACE FUNCTION update_task_completion_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-update assignment status when task is completed
    IF NEW.task_finished_completed = true AND 
       NEW.photo_uploaded_completed = true AND 
       NEW.erp_reference_completed = true THEN
        
        UPDATE public.task_assignments 
        SET status = 'completed',
            completed_at = NEW.completed_at
        WHERE id = NEW.assignment_id;
    END IF;
    
    -- Auto-set verification timestamp
    IF NEW.verified_by IS NOT NULL AND OLD.verified_by IS NULL THEN
        NEW.verified_at = COALESCE(NEW.verified_at, now());
    END IF;
    
    -- Clear verification if verifier is removed
    IF NEW.verified_by IS NULL AND OLD.verified_by IS NOT NULL THEN
        NEW.verified_at = NULL;
        NEW.verification_notes = NULL;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic completion status management
CREATE TRIGGER trigger_task_completion_status_management
    BEFORE UPDATE ON public.task_completions
    FOR EACH ROW
    EXECUTE FUNCTION update_task_completion_status();

-- =====================================================
-- Functions for Completion Management
-- =====================================================

-- Function to create task completion record
CREATE OR REPLACE FUNCTION create_task_completion(
    p_task_id UUID,
    p_assignment_id UUID,
    p_completed_by TEXT,
    p_completed_by_name TEXT DEFAULT NULL,
    p_completed_by_branch_id UUID DEFAULT NULL,
    p_completion_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    completion_id UUID;
BEGIN
    INSERT INTO public.task_completions (
        task_id, assignment_id, completed_by, completed_by_name, 
        completed_by_branch_id, completion_notes
    ) VALUES (
        p_task_id, p_assignment_id, p_completed_by, p_completed_by_name,
        p_completed_by_branch_id, p_completion_notes
    )
    ON CONFLICT (task_id, completed_by) 
    DO UPDATE SET
        assignment_id = EXCLUDED.assignment_id,
        completed_by_name = EXCLUDED.completed_by_name,
        completed_by_branch_id = EXCLUDED.completed_by_branch_id,
        completion_notes = EXCLUDED.completion_notes,
        completed_at = now()
    RETURNING id INTO completion_id;
    
    RETURN completion_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update completion step
CREATE OR REPLACE FUNCTION update_completion_step(
    p_completion_id UUID,
    p_step_name TEXT,
    p_step_completed BOOLEAN,
    p_erp_reference_number TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    CASE p_step_name
        WHEN 'task_finished' THEN
            UPDATE public.task_completions 
            SET task_finished_completed = p_step_completed
            WHERE id = p_completion_id;
        WHEN 'photo_uploaded' THEN
            UPDATE public.task_completions 
            SET photo_uploaded_completed = p_step_completed
            WHERE id = p_completion_id;
        WHEN 'erp_reference' THEN
            UPDATE public.task_completions 
            SET erp_reference_completed = p_step_completed,
                erp_reference_number = p_erp_reference_number
            WHERE id = p_completion_id;
        ELSE
            RETURN false;
    END CASE;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to verify task completion
CREATE OR REPLACE FUNCTION verify_task_completion(
    p_completion_id UUID,
    p_verified_by TEXT,
    p_verification_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.task_completions 
    SET verified_by = p_verified_by,
        verified_at = now(),
        verification_notes = p_verification_notes
    WHERE id = p_completion_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Function to get completion progress
CREATE OR REPLACE FUNCTION get_completion_progress(p_completion_id UUID)
RETURNS TABLE (
    completion_id UUID,
    task_finished BOOLEAN,
    photo_uploaded BOOLEAN,
    erp_reference BOOLEAN,
    overall_progress NUMERIC,
    is_fully_completed BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tc.id as completion_id,
        COALESCE(tc.task_finished_completed, false) as task_finished,
        COALESCE(tc.photo_uploaded_completed, false) as photo_uploaded,
        COALESCE(tc.erp_reference_completed, false) as erp_reference,
        ROUND(
            (CASE WHEN tc.task_finished_completed THEN 1 ELSE 0 END +
             CASE WHEN tc.photo_uploaded_completed THEN 1 ELSE 0 END +
             CASE WHEN tc.erp_reference_completed THEN 1 ELSE 0 END) * 100.0 / 3, 2
        ) as overall_progress,
        (tc.task_finished_completed = true AND 
         tc.photo_uploaded_completed = true AND 
         tc.erp_reference_completed = true) as is_fully_completed
    FROM public.task_completions tc
    WHERE tc.id = p_completion_id;
END;
$$ LANGUAGE plpgsql;

-- Function to get user completion statistics
CREATE OR REPLACE FUNCTION get_user_completion_stats(
    p_user_id TEXT,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS TABLE (
    total_completions INTEGER,
    verified_completions INTEGER,
    pending_verification INTEGER,
    avg_completion_time INTERVAL,
    completion_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_completions,
        COUNT(CASE WHEN tc.verified_by IS NOT NULL THEN 1 END)::INTEGER as verified_completions,
        COUNT(CASE WHEN tc.verified_by IS NULL THEN 1 END)::INTEGER as pending_verification,
        AVG(tc.completed_at - tc.created_at) as avg_completion_time,
        ROUND(
            COUNT(CASE WHEN tc.task_finished_completed = true AND 
                              tc.photo_uploaded_completed = true AND 
                              tc.erp_reference_completed = true THEN 1 END) * 100.0 / 
            NULLIF(COUNT(*), 0), 2
        ) as completion_rate
    FROM public.task_completions tc
    WHERE tc.completed_by = p_user_id
      AND (p_start_date IS NULL OR tc.completed_at >= p_start_date)
      AND (p_end_date IS NULL OR tc.completed_at <= p_end_date);
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Views for Common Completion Queries
-- =====================================================

-- View for completion summary with task details
CREATE OR REPLACE VIEW task_completion_summary AS
SELECT 
    tc.id as completion_id,
    tc.task_id,
    t.title as task_title,
    t.priority as task_priority,
    tc.assignment_id,
    tc.completed_by,
    tc.completed_by_name,
    tc.completed_by_branch_id,
    b.name_en as branch_name,
    tc.task_finished_completed,
    tc.photo_uploaded_completed,
    tc.erp_reference_completed,
    tc.erp_reference_number,
    tc.completion_notes,
    tc.verified_by,
    tc.verified_at,
    tc.verification_notes,
    tc.completed_at,
    ROUND(
        (CASE WHEN tc.task_finished_completed THEN 1 ELSE 0 END +
         CASE WHEN tc.photo_uploaded_completed THEN 1 ELSE 0 END +
         CASE WHEN tc.erp_reference_completed THEN 1 ELSE 0 END) * 100.0 / 3, 2
    ) as completion_percentage,
    (tc.task_finished_completed = true AND 
     tc.photo_uploaded_completed = true AND 
     tc.erp_reference_completed = true) as is_fully_completed
FROM public.task_completions tc
JOIN public.tasks t ON tc.task_id = t.id
LEFT JOIN public.branches b ON tc.completed_by_branch_id = b.id
ORDER BY tc.completed_at DESC;

-- =====================================================
-- Table Comments for Documentation
-- =====================================================

COMMENT ON TABLE public.task_completions IS 'Task completion tracking and verification system with multi-step completion process';

COMMENT ON COLUMN public.task_completions.id IS 'Primary key - unique identifier for each task completion record';
COMMENT ON COLUMN public.task_completions.task_id IS 'Foreign key to tasks table - which task was completed';
COMMENT ON COLUMN public.task_completions.assignment_id IS 'Foreign key to task_assignments table - which assignment was completed';
COMMENT ON COLUMN public.task_completions.completed_by IS 'User ID of the person who completed the task';
COMMENT ON COLUMN public.task_completions.completed_by_name IS 'Display name of the person who completed the task';
COMMENT ON COLUMN public.task_completions.completed_by_branch_id IS 'Branch ID where the task was completed';
COMMENT ON COLUMN public.task_completions.task_finished_completed IS 'Boolean flag for task completion step';
COMMENT ON COLUMN public.task_completions.photo_uploaded_completed IS 'Boolean flag for photo upload completion step';
COMMENT ON COLUMN public.task_completions.erp_reference_completed IS 'Boolean flag for ERP reference completion step';
COMMENT ON COLUMN public.task_completions.erp_reference_number IS 'ERP system reference number for the completed task';
COMMENT ON COLUMN public.task_completions.completion_notes IS 'Additional notes about the task completion';
COMMENT ON COLUMN public.task_completions.verified_by IS 'User ID of the person who verified the completion';
COMMENT ON COLUMN public.task_completions.verified_at IS 'Timestamp when the completion was verified';
COMMENT ON COLUMN public.task_completions.verification_notes IS 'Notes from the verification process';
COMMENT ON COLUMN public.task_completions.completed_at IS 'Timestamp when the task was completed';
COMMENT ON COLUMN public.task_completions.created_at IS 'Timestamp when the completion record was created';

-- Function comments
COMMENT ON FUNCTION create_task_completion(UUID, UUID, TEXT, TEXT, UUID, TEXT) IS 'Creates a new task completion record with upsert logic';
COMMENT ON FUNCTION update_completion_step(UUID, TEXT, BOOLEAN, TEXT) IS 'Updates individual completion steps (task_finished, photo_uploaded, erp_reference)';
COMMENT ON FUNCTION verify_task_completion(UUID, TEXT, TEXT) IS 'Verifies a task completion with verifier details and notes';
COMMENT ON FUNCTION get_completion_progress(UUID) IS 'Returns completion progress percentage and step details';
COMMENT ON FUNCTION get_user_completion_stats(TEXT, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) IS 'Returns comprehensive completion statistics for a user';

-- View comments
COMMENT ON VIEW task_completion_summary IS 'Comprehensive view of task completions with task details, progress, and verification status';