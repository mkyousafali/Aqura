-- Create task_completions table for tracking task completion details
-- This table stores comprehensive information about how tasks were completed and verified

-- Create the task_completions table
CREATE TABLE IF NOT EXISTS public.task_completions (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL,
    assignment_id UUID NOT NULL,
    completed_by TEXT NOT NULL,
    completed_by_name TEXT NULL,
    completed_by_branch_id UUID NULL,
    task_finished_completed BOOLEAN NULL DEFAULT false,
    photo_uploaded_completed BOOLEAN NULL DEFAULT false,
    erp_reference_completed BOOLEAN NULL DEFAULT false,
    erp_reference_number TEXT NULL,
    completion_notes TEXT NULL,
    verified_by TEXT NULL,
    verified_at TIMESTAMP WITH TIME ZONE NULL,
    verification_notes TEXT NULL,
    completed_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE NULL DEFAULT now(),
    completion_photo_url TEXT NULL,
    
    CONSTRAINT task_completions_pkey PRIMARY KEY (id),
    CONSTRAINT task_completions_assignment_id_fkey 
        FOREIGN KEY (assignment_id) REFERENCES task_assignments (id) ON DELETE CASCADE,
    CONSTRAINT task_completions_task_id_fkey 
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT chk_photo_url_consistency 
        CHECK (photo_uploaded_completed = false OR completion_photo_url IS NOT NULL)
) TABLESPACE pg_default;

-- Create indexes for efficient queries (original indexes)
CREATE INDEX IF NOT EXISTS idx_task_completions_task_id 
ON public.task_completions USING btree (task_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_assignment_id 
ON public.task_completions USING btree (assignment_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_completed_by 
ON public.task_completions USING btree (completed_by) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_completed_by_branch_id 
ON public.task_completions USING btree (completed_by_branch_id) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_task_finished 
ON public.task_completions USING btree (task_finished_completed) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_photo_uploaded 
ON public.task_completions USING btree (photo_uploaded_completed) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_erp_reference 
ON public.task_completions USING btree (erp_reference_completed) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_completed_at 
ON public.task_completions USING btree (completed_at DESC) 
TABLESPACE pg_default;

CREATE INDEX IF NOT EXISTS idx_task_completions_photo_url 
ON public.task_completions USING btree (completion_photo_url) 
TABLESPACE pg_default
WHERE completion_photo_url IS NOT NULL;

-- Create additional useful indexes
CREATE INDEX IF NOT EXISTS idx_task_completions_verified_by 
ON public.task_completions (verified_by);

CREATE INDEX IF NOT EXISTS idx_task_completions_verified_at 
ON public.task_completions (verified_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_completions_created_at 
ON public.task_completions (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_completions_erp_number 
ON public.task_completions (erp_reference_number);

-- Create composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_task_completions_task_assignment 
ON public.task_completions (task_id, assignment_id);

CREATE INDEX IF NOT EXISTS idx_task_completions_completed_by_date 
ON public.task_completions (completed_by, completed_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_completions_branch_date 
ON public.task_completions (completed_by_branch_id, completed_at DESC);

CREATE INDEX IF NOT EXISTS idx_task_completions_verification_status 
ON public.task_completions (verified_by, verified_at DESC);

-- Create partial indexes for performance
CREATE INDEX IF NOT EXISTS idx_task_completions_verified 
ON public.task_completions (verified_at DESC) 
WHERE verified_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_completions_unverified 
ON public.task_completions (completed_at DESC) 
WHERE verified_by IS NULL;

CREATE INDEX IF NOT EXISTS idx_task_completions_with_photo 
ON public.task_completions (completed_at DESC) 
WHERE photo_uploaded_completed = true;

CREATE INDEX IF NOT EXISTS idx_task_completions_with_erp 
ON public.task_completions (completed_at DESC) 
WHERE erp_reference_completed = true;

CREATE INDEX IF NOT EXISTS idx_task_completions_complete_requirements 
ON public.task_completions (completed_at DESC) 
WHERE task_finished_completed = true AND photo_uploaded_completed = true AND erp_reference_completed = true;

-- Add updated_at column and trigger
ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT now();

CREATE OR REPLACE FUNCTION update_task_completions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_task_completions_updated_at 
BEFORE UPDATE ON task_completions 
FOR EACH ROW 
EXECUTE FUNCTION update_task_completions_updated_at();

-- Add additional validation constraints
ALTER TABLE public.task_completions 
ADD CONSTRAINT chk_verification_sequence 
CHECK (verified_at IS NULL OR verified_at >= completed_at);

ALTER TABLE public.task_completions 
ADD CONSTRAINT chk_erp_number_when_completed 
CHECK (erp_reference_completed = false OR erp_reference_number IS NOT NULL);

ALTER TABLE public.task_completions 
ADD CONSTRAINT chk_completion_at_sequence 
CHECK (completed_at >= created_at);

-- Add additional columns for enhanced functionality
ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS completion_quality_score INTEGER;

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS completion_duration INTERVAL;

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS location_coordinates POINT;

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS location_address TEXT;

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS device_info JSONB DEFAULT '{}';

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS completion_metadata JSONB DEFAULT '{}';

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS additional_photos TEXT[];

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS completion_rating INTEGER;

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS completion_feedback TEXT;

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS is_revision BOOLEAN DEFAULT false;

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS revision_reason TEXT;

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS original_completion_id UUID;

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS approval_status VARCHAR(50) DEFAULT 'pending';

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS approved_by TEXT;

ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE;

-- Add foreign keys for new columns
ALTER TABLE public.task_completions 
ADD CONSTRAINT task_completions_completed_by_branch_id_fkey 
FOREIGN KEY (completed_by_branch_id) REFERENCES branches (id) ON DELETE SET NULL;

ALTER TABLE public.task_completions 
ADD CONSTRAINT task_completions_original_completion_id_fkey 
FOREIGN KEY (original_completion_id) REFERENCES task_completions (id) ON DELETE SET NULL;

-- Add validation for new columns
ALTER TABLE public.task_completions 
ADD CONSTRAINT chk_completion_quality_score_valid 
CHECK (completion_quality_score IS NULL OR (completion_quality_score >= 1 AND completion_quality_score <= 10));

ALTER TABLE public.task_completions 
ADD CONSTRAINT chk_completion_rating_valid 
CHECK (completion_rating IS NULL OR (completion_rating >= 1 AND completion_rating <= 5));

ALTER TABLE public.task_completions 
ADD CONSTRAINT chk_approval_status_valid 
CHECK (approval_status IN ('pending', 'approved', 'rejected', 'needs_revision'));

ALTER TABLE public.task_completions 
ADD CONSTRAINT chk_approval_sequence 
CHECK (approved_at IS NULL OR approved_at >= completed_at);

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_task_completions_quality_score 
ON public.task_completions (completion_quality_score);

CREATE INDEX IF NOT EXISTS idx_task_completions_location 
ON public.task_completions USING gist (location_coordinates);

CREATE INDEX IF NOT EXISTS idx_task_completions_rating 
ON public.task_completions (completion_rating);

CREATE INDEX IF NOT EXISTS idx_task_completions_revision 
ON public.task_completions (is_revision) 
WHERE is_revision = true;

CREATE INDEX IF NOT EXISTS idx_task_completions_original 
ON public.task_completions (original_completion_id) 
WHERE original_completion_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_task_completions_approval_status 
ON public.task_completions (approval_status);

CREATE INDEX IF NOT EXISTS idx_task_completions_approved_by 
ON public.task_completions (approved_by);

CREATE INDEX IF NOT EXISTS idx_task_completions_approved_at 
ON public.task_completions (approved_at DESC);

-- Create GIN indexes for arrays and JSONB
CREATE INDEX IF NOT EXISTS idx_task_completions_additional_photos 
ON public.task_completions USING gin (additional_photos);

CREATE INDEX IF NOT EXISTS idx_task_completions_device_info 
ON public.task_completions USING gin (device_info);

CREATE INDEX IF NOT EXISTS idx_task_completions_metadata 
ON public.task_completions USING gin (completion_metadata);

-- Add table and column comments
COMMENT ON TABLE public.task_completions IS 'Comprehensive task completion tracking with verification and quality control';
COMMENT ON COLUMN public.task_completions.id IS 'Unique identifier for the completion record';
COMMENT ON COLUMN public.task_completions.task_id IS 'Reference to the completed task';
COMMENT ON COLUMN public.task_completions.assignment_id IS 'Reference to the specific assignment';
COMMENT ON COLUMN public.task_completions.completed_by IS 'User who completed the task';
COMMENT ON COLUMN public.task_completions.completed_by_name IS 'Name of the user who completed the task';
COMMENT ON COLUMN public.task_completions.completed_by_branch_id IS 'Branch of the user who completed the task';
COMMENT ON COLUMN public.task_completions.task_finished_completed IS 'Whether the main task was finished';
COMMENT ON COLUMN public.task_completions.photo_uploaded_completed IS 'Whether photo upload requirement was met';
COMMENT ON COLUMN public.task_completions.erp_reference_completed IS 'Whether ERP reference requirement was met';
COMMENT ON COLUMN public.task_completions.erp_reference_number IS 'ERP reference number if applicable';
COMMENT ON COLUMN public.task_completions.completion_notes IS 'Notes added during completion';
COMMENT ON COLUMN public.task_completions.verified_by IS 'User who verified the completion';
COMMENT ON COLUMN public.task_completions.verified_at IS 'When the completion was verified';
COMMENT ON COLUMN public.task_completions.verification_notes IS 'Notes added during verification';
COMMENT ON COLUMN public.task_completions.completed_at IS 'When the task was completed';
COMMENT ON COLUMN public.task_completions.completion_photo_url IS 'URL of the completion photo';
COMMENT ON COLUMN public.task_completions.completion_quality_score IS 'Quality score (1-10)';
COMMENT ON COLUMN public.task_completions.completion_duration IS 'Time taken to complete the task';
COMMENT ON COLUMN public.task_completions.location_coordinates IS 'GPS coordinates where task was completed';
COMMENT ON COLUMN public.task_completions.location_address IS 'Address where task was completed';
COMMENT ON COLUMN public.task_completions.device_info IS 'Information about the device used';
COMMENT ON COLUMN public.task_completions.completion_metadata IS 'Additional metadata as JSON';
COMMENT ON COLUMN public.task_completions.additional_photos IS 'Array of additional photo URLs';
COMMENT ON COLUMN public.task_completions.completion_rating IS 'User rating of the completion (1-5)';
COMMENT ON COLUMN public.task_completions.completion_feedback IS 'User feedback about the completion';
COMMENT ON COLUMN public.task_completions.is_revision IS 'Whether this is a revision of a previous completion';
COMMENT ON COLUMN public.task_completions.revision_reason IS 'Reason for revision if applicable';
COMMENT ON COLUMN public.task_completions.original_completion_id IS 'Original completion if this is a revision';
COMMENT ON COLUMN public.task_completions.approval_status IS 'Current approval status';
COMMENT ON COLUMN public.task_completions.approved_by IS 'User who approved the completion';
COMMENT ON COLUMN public.task_completions.approved_at IS 'When the completion was approved';
COMMENT ON COLUMN public.task_completions.created_at IS 'When the completion record was created';
COMMENT ON COLUMN public.task_completions.updated_at IS 'When the completion record was last updated';

-- Create comprehensive view for completions with related data
CREATE OR REPLACE VIEW task_completions_detailed AS
SELECT 
    tc.id,
    tc.task_id,
    t.name as task_name,
    t.description as task_description,
    tc.assignment_id,
    ta.assignment_type,
    tc.completed_by,
    tc.completed_by_name,
    tc.completed_by_branch_id,
    cb.name as completed_by_branch_name,
    tc.task_finished_completed,
    tc.photo_uploaded_completed,
    tc.erp_reference_completed,
    tc.erp_reference_number,
    tc.completion_notes,
    tc.verified_by,
    tc.verified_at,
    tc.verification_notes,
    tc.completion_photo_url,
    tc.additional_photos,
    tc.completion_quality_score,
    tc.completion_duration,
    tc.location_coordinates,
    tc.location_address,
    tc.device_info,
    tc.completion_metadata,
    tc.completion_rating,
    tc.completion_feedback,
    tc.is_revision,
    tc.revision_reason,
    tc.original_completion_id,
    tc.approval_status,
    tc.approved_by,
    tc.approved_at,
    tc.completed_at,
    tc.created_at,
    tc.updated_at,
    CASE 
        WHEN tc.task_finished_completed AND 
             (NOT ta.require_photo_upload OR tc.photo_uploaded_completed) AND 
             (NOT ta.require_erp_reference OR tc.erp_reference_completed) 
        THEN true
        ELSE false
    END as all_requirements_met,
    CASE 
        WHEN tc.verified_by IS NOT NULL THEN true
        ELSE false
    END as is_verified,
    EXTRACT(EPOCH FROM (tc.completed_at - ta.assigned_at)) / 3600 as completion_time_hours
FROM task_completions tc
LEFT JOIN tasks t ON tc.task_id = t.id
LEFT JOIN task_assignments ta ON tc.assignment_id = ta.id
LEFT JOIN branches cb ON tc.completed_by_branch_id = cb.id
ORDER BY tc.completed_at DESC;

-- Create function to complete a task
CREATE OR REPLACE FUNCTION complete_task(
    task_id_param UUID,
    assignment_id_param UUID,
    completed_by_param TEXT,
    completed_by_name_param TEXT DEFAULT NULL,
    completion_notes_param TEXT DEFAULT NULL,
    photo_url_param TEXT DEFAULT NULL,
    erp_reference_param TEXT DEFAULT NULL,
    location_coords POINT DEFAULT NULL,
    location_addr TEXT DEFAULT NULL,
    quality_score INTEGER DEFAULT NULL,
    rating INTEGER DEFAULT NULL,
    feedback TEXT DEFAULT NULL,
    metadata_param JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    completion_id UUID;
    assignment_rec RECORD;
BEGIN
    -- Get assignment requirements
    SELECT * INTO assignment_rec 
    FROM task_assignments 
    WHERE id = assignment_id_param;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Assignment not found';
    END IF;
    
    INSERT INTO task_completions (
        task_id,
        assignment_id,
        completed_by,
        completed_by_name,
        task_finished_completed,
        photo_uploaded_completed,
        erp_reference_completed,
        erp_reference_number,
        completion_notes,
        completion_photo_url,
        location_coordinates,
        location_address,
        completion_quality_score,
        completion_rating,
        completion_feedback,
        completion_metadata
    ) VALUES (
        task_id_param,
        assignment_id_param,
        completed_by_param,
        completed_by_name_param,
        true, -- task always finished when completing
        CASE WHEN assignment_rec.require_photo_upload THEN (photo_url_param IS NOT NULL) ELSE false END,
        CASE WHEN assignment_rec.require_erp_reference THEN (erp_reference_param IS NOT NULL) ELSE false END,
        erp_reference_param,
        completion_notes_param,
        photo_url_param,
        location_coords,
        location_addr,
        quality_score,
        rating,
        feedback,
        metadata_param
    ) RETURNING id INTO completion_id;
    
    -- Update assignment status
    UPDATE task_assignments 
    SET status = 'completed',
        completed_at = now(),
        last_activity_at = now()
    WHERE id = assignment_id_param;
    
    RETURN completion_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to verify a completion
CREATE OR REPLACE FUNCTION verify_completion(
    completion_id UUID,
    verified_by_param TEXT,
    verification_notes_param TEXT DEFAULT NULL,
    approval_status_param VARCHAR DEFAULT 'approved'
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE task_completions 
    SET verified_by = verified_by_param,
        verified_at = now(),
        verification_notes = verification_notes_param,
        approval_status = approval_status_param,
        approved_by = CASE WHEN approval_status_param = 'approved' THEN verified_by_param ELSE approved_by END,
        approved_at = CASE WHEN approval_status_param = 'approved' THEN now() ELSE approved_at END,
        updated_at = now()
    WHERE id = completion_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to create a revision
CREATE OR REPLACE FUNCTION create_completion_revision(
    original_completion_id UUID,
    revision_reason_param TEXT,
    completed_by_param TEXT,
    completion_notes_param TEXT DEFAULT NULL,
    photo_url_param TEXT DEFAULT NULL,
    erp_reference_param TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    original_completion RECORD;
    revision_id UUID;
    assignment_rec RECORD;
BEGIN
    -- Get original completion
    SELECT * INTO original_completion 
    FROM task_completions 
    WHERE id = original_completion_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Original completion not found';
    END IF;
    
    -- Get assignment requirements
    SELECT * INTO assignment_rec 
    FROM task_assignments 
    WHERE id = original_completion.assignment_id;
    
    INSERT INTO task_completions (
        task_id,
        assignment_id,
        completed_by,
        task_finished_completed,
        photo_uploaded_completed,
        erp_reference_completed,
        erp_reference_number,
        completion_notes,
        completion_photo_url,
        is_revision,
        revision_reason,
        original_completion_id,
        approval_status
    ) VALUES (
        original_completion.task_id,
        original_completion.assignment_id,
        completed_by_param,
        true,
        CASE WHEN assignment_rec.require_photo_upload THEN (photo_url_param IS NOT NULL) ELSE false END,
        CASE WHEN assignment_rec.require_erp_reference THEN (erp_reference_param IS NOT NULL) ELSE false END,
        erp_reference_param,
        completion_notes_param,
        photo_url_param,
        true,
        revision_reason_param,
        original_completion_id,
        'pending'
    ) RETURNING id INTO revision_id;
    
    -- Mark original as needing revision
    UPDATE task_completions 
    SET approval_status = 'needs_revision',
        updated_at = now()
    WHERE id = original_completion_id;
    
    RETURN revision_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to get completion statistics
CREATE OR REPLACE FUNCTION get_completion_statistics(
    user_id_param TEXT DEFAULT NULL,
    branch_id_param UUID DEFAULT NULL,
    date_from TIMESTAMPTZ DEFAULT NULL,
    date_to TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(
    total_completions BIGINT,
    verified_completions BIGINT,
    approved_completions BIGINT,
    rejected_completions BIGINT,
    revision_completions BIGINT,
    with_photo_completions BIGINT,
    with_erp_completions BIGINT,
    avg_quality_score DECIMAL,
    avg_completion_rating DECIMAL,
    avg_completion_duration INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_completions,
        COUNT(*) FILTER (WHERE verified_by IS NOT NULL) as verified_completions,
        COUNT(*) FILTER (WHERE approval_status = 'approved') as approved_completions,
        COUNT(*) FILTER (WHERE approval_status = 'rejected') as rejected_completions,
        COUNT(*) FILTER (WHERE is_revision = true) as revision_completions,
        COUNT(*) FILTER (WHERE photo_uploaded_completed = true) as with_photo_completions,
        COUNT(*) FILTER (WHERE erp_reference_completed = true) as with_erp_completions,
        AVG(completion_quality_score) FILTER (WHERE completion_quality_score IS NOT NULL) as avg_quality_score,
        AVG(completion_rating) FILTER (WHERE completion_rating IS NOT NULL) as avg_completion_rating,
        AVG(completion_duration) FILTER (WHERE completion_duration IS NOT NULL) as avg_completion_duration
    FROM task_completions
    WHERE (user_id_param IS NULL OR completed_by = user_id_param)
      AND (branch_id_param IS NULL OR completed_by_branch_id = branch_id_param)
      AND (date_from IS NULL OR completed_at >= date_from)
      AND (date_to IS NULL OR completed_at <= date_to);
END;
$$ LANGUAGE plpgsql;

-- Create function to get pending verifications
CREATE OR REPLACE FUNCTION get_pending_verifications(
    limit_param INTEGER DEFAULT 50
)
RETURNS TABLE(
    completion_id UUID,
    task_name VARCHAR,
    completed_by TEXT,
    completed_by_name TEXT,
    completed_at TIMESTAMPTZ,
    hours_since_completion DECIMAL,
    all_requirements_met BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tc.id,
        t.name as task_name,
        tc.completed_by,
        tc.completed_by_name,
        tc.completed_at,
        EXTRACT(EPOCH FROM (now() - tc.completed_at)) / 3600 as hours_since_completion,
        CASE 
            WHEN tc.task_finished_completed AND 
                 (NOT ta.require_photo_upload OR tc.photo_uploaded_completed) AND 
                 (NOT ta.require_erp_reference OR tc.erp_reference_completed) 
            THEN true
            ELSE false
        END as all_requirements_met
    FROM task_completions tc
    LEFT JOIN tasks t ON tc.task_id = t.id
    LEFT JOIN task_assignments ta ON tc.assignment_id = ta.id
    WHERE tc.verified_by IS NULL 
      AND tc.approval_status = 'pending'
      AND tc.is_revision = false
    ORDER BY tc.completed_at ASC
    LIMIT limit_param;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'task_completions table created with comprehensive completion tracking and verification features';