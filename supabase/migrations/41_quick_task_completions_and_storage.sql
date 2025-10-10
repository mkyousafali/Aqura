-- Migration 41: Quick Task Completions Table and Storage Bucket Policies
-- Creates quick_task_completions table and sets up storage bucket for completion photos

-- Create storage bucket for completion photos
INSERT INTO storage.buckets (id, name, public)
VALUES ('completion-photos', 'completion-photos', false)
ON CONFLICT (id) DO NOTHING;

-- Create RLS policies for completion-photos bucket
CREATE POLICY "Authenticated users can manage completion photos" ON storage.objects
FOR ALL USING (
    bucket_id = 'completion-photos' 
    AND auth.role() = 'authenticated'
);

-- Create quick_task_completions table
CREATE TABLE IF NOT EXISTS public.quick_task_completions (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    quick_task_id UUID NOT NULL,
    assignment_id UUID NOT NULL,
    completed_by_user_id UUID NOT NULL,
    completion_notes TEXT,
    photo_path TEXT,
    erp_reference VARCHAR(255),
    completion_status VARCHAR(50) NOT NULL DEFAULT 'submitted',
    verified_by_user_id UUID,
    verified_at TIMESTAMP WITH TIME ZONE,
    verification_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    
    CONSTRAINT quick_task_completions_pkey PRIMARY KEY (id),
    CONSTRAINT quick_task_completions_quick_task_id_fkey 
        FOREIGN KEY (quick_task_id) REFERENCES quick_tasks (id) ON DELETE CASCADE,
    CONSTRAINT quick_task_completions_assignment_id_fkey 
        FOREIGN KEY (assignment_id) REFERENCES quick_task_assignments (id) ON DELETE CASCADE,
    CONSTRAINT quick_task_completions_completed_by_user_id_fkey 
        FOREIGN KEY (completed_by_user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT quick_task_completions_verified_by_user_id_fkey 
        FOREIGN KEY (verified_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT quick_task_completions_assignment_unique 
        UNIQUE (assignment_id)
);

-- Create indexes for quick_task_completions
CREATE INDEX IF NOT EXISTS idx_quick_task_completions_task 
ON public.quick_task_completions USING btree (quick_task_id);

CREATE INDEX IF NOT EXISTS idx_quick_task_completions_assignment 
ON public.quick_task_completions USING btree (assignment_id);

CREATE INDEX IF NOT EXISTS idx_quick_task_completions_completed_by 
ON public.quick_task_completions USING btree (completed_by_user_id);

CREATE INDEX IF NOT EXISTS idx_quick_task_completions_status 
ON public.quick_task_completions USING btree (completion_status);

CREATE INDEX IF NOT EXISTS idx_quick_task_completions_created_at 
ON public.quick_task_completions USING btree (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_quick_task_completions_verified_by 
ON public.quick_task_completions USING btree (verified_by_user_id) 
WHERE verified_by_user_id IS NOT NULL;

-- Add constraints
ALTER TABLE public.quick_task_completions 
ADD CONSTRAINT chk_completion_status_valid 
CHECK (completion_status IN (
    'submitted', 'verified', 'rejected', 'pending_review'
));

ALTER TABLE public.quick_task_completions 
ADD CONSTRAINT chk_verified_at_when_verified 
CHECK (
    (completion_status != 'verified' AND verified_at IS NULL) OR
    (completion_status = 'verified' AND verified_at IS NOT NULL)
);

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_quick_task_completions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    
    -- Auto-set verification timestamp
    IF NEW.completion_status = 'verified' AND OLD.completion_status != 'verified' AND NEW.verified_at IS NULL THEN
        NEW.verified_at = now();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_quick_task_completions_updated_at 
BEFORE UPDATE ON quick_task_completions 
FOR EACH ROW 
EXECUTE FUNCTION update_quick_task_completions_updated_at();

-- Add table and column comments
COMMENT ON TABLE public.quick_task_completions IS 'Completion records for quick tasks with photos and verification';
COMMENT ON COLUMN public.quick_task_completions.id IS 'Unique identifier for the completion record';
COMMENT ON COLUMN public.quick_task_completions.quick_task_id IS 'Reference to the quick task that was completed';
COMMENT ON COLUMN public.quick_task_completions.assignment_id IS 'Reference to the specific assignment that was completed';
COMMENT ON COLUMN public.quick_task_completions.completed_by_user_id IS 'User who completed the task';
COMMENT ON COLUMN public.quick_task_completions.completion_notes IS 'Notes provided by the user upon completion';
COMMENT ON COLUMN public.quick_task_completions.photo_path IS 'Path to the completion photo in storage';
COMMENT ON COLUMN public.quick_task_completions.erp_reference IS 'ERP system reference number if required';
COMMENT ON COLUMN public.quick_task_completions.completion_status IS 'Status of the completion record';
COMMENT ON COLUMN public.quick_task_completions.verified_by_user_id IS 'User who verified the completion';
COMMENT ON COLUMN public.quick_task_completions.verified_at IS 'When the completion was verified';
COMMENT ON COLUMN public.quick_task_completions.verification_notes IS 'Notes from the verifier';

-- Create view for completion details
CREATE OR REPLACE VIEW quick_task_completion_details AS
SELECT 
    qtc.id,
    qtc.quick_task_id,
    qt.title as task_title,
    qt.description as task_description,
    qtc.assignment_id,
    qtc.completed_by_user_id,
    u1.username as completed_by_username,
    u1.username as completed_by_name,
    qtc.completion_notes,
    qtc.photo_path,
    qtc.erp_reference,
    qtc.completion_status,
    qtc.verified_by_user_id,
    u2.username as verified_by_username,
    u2.username as verified_by_name,
    qtc.verified_at,
    qtc.verification_notes,
    qtc.created_at,
    qtc.updated_at,
    qta.require_photo_upload,
    qta.require_erp_reference,
    qta.require_task_finished
FROM quick_task_completions qtc
JOIN quick_tasks qt ON qtc.quick_task_id = qt.id
JOIN quick_task_assignments qta ON qtc.assignment_id = qta.id
JOIN users u1 ON qtc.completed_by_user_id = u1.id
LEFT JOIN users u2 ON qtc.verified_by_user_id = u2.id
ORDER BY qtc.created_at DESC;

-- Create function to submit quick task completion
CREATE OR REPLACE FUNCTION submit_quick_task_completion(
    assignment_id_param UUID,
    completion_notes_param TEXT DEFAULT NULL,
    photo_path_param TEXT DEFAULT NULL,
    erp_reference_param TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    completion_id UUID;
    task_id UUID;
    user_id UUID;
    requires_photo BOOLEAN;
    requires_erp BOOLEAN;
BEGIN
    -- Get current user from auth
    user_id := auth.uid();
    
    -- Get assignment details
    SELECT qta.quick_task_id, qta.require_photo_upload, qta.require_erp_reference
    INTO task_id, requires_photo, requires_erp
    FROM quick_task_assignments qta
    WHERE qta.id = assignment_id_param;
    
    -- Check if assignment exists
    IF task_id IS NULL THEN
        RAISE EXCEPTION 'Assignment not found with ID: %', assignment_id_param;
    END IF;
    
    -- Validate requirements
    IF requires_photo AND photo_path_param IS NULL THEN
        RAISE EXCEPTION 'Photo upload is required for this task';
    END IF;
    
    IF requires_erp AND erp_reference_param IS NULL THEN
        RAISE EXCEPTION 'ERP reference is required for this task';
    END IF;
    
    -- Insert completion record
    INSERT INTO quick_task_completions (
        quick_task_id,
        assignment_id,
        completed_by_user_id,
        completion_notes,
        photo_path,
        erp_reference,
        completion_status
    ) VALUES (
        task_id,
        assignment_id_param,
        user_id,
        completion_notes_param,
        photo_path_param,
        erp_reference_param,
        'submitted'
    ) RETURNING id INTO completion_id;
    
    -- Update assignment status to completed
    UPDATE quick_task_assignments 
    SET status = 'completed',
        completed_at = now(),
        updated_at = now()
    WHERE id = assignment_id_param;
    
    RETURN completion_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to verify completion
CREATE OR REPLACE FUNCTION verify_quick_task_completion(
    completion_id_param UUID,
    verified_by_user_id_param UUID,
    verification_notes_param TEXT DEFAULT NULL,
    is_approved BOOLEAN DEFAULT true
)
RETURNS BOOLEAN AS $$
DECLARE
    new_status VARCHAR(50);
BEGIN
    IF is_approved THEN
        new_status := 'verified';
    ELSE
        new_status := 'rejected';
    END IF;
    
    UPDATE quick_task_completions 
    SET completion_status = new_status,
        verified_by_user_id = verified_by_user_id_param,
        verified_at = now(),
        verification_notes = verification_notes_param,
        updated_at = now()
    WHERE id = completion_id_param;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Create function to get completion statistics
CREATE OR REPLACE FUNCTION get_quick_task_completion_stats()
RETURNS TABLE(
    total_completions BIGINT,
    submitted_count BIGINT,
    verified_count BIGINT,
    rejected_count BIGINT,
    pending_review_count BIGINT,
    completions_with_photos BIGINT,
    completions_with_erp BIGINT,
    avg_verification_time INTERVAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_completions,
        COUNT(*) FILTER (WHERE completion_status = 'submitted') as submitted_count,
        COUNT(*) FILTER (WHERE completion_status = 'verified') as verified_count,
        COUNT(*) FILTER (WHERE completion_status = 'rejected') as rejected_count,
        COUNT(*) FILTER (WHERE completion_status = 'pending_review') as pending_review_count,
        COUNT(*) FILTER (WHERE photo_path IS NOT NULL) as completions_with_photos,
        COUNT(*) FILTER (WHERE erp_reference IS NOT NULL) as completions_with_erp,
        AVG(verified_at - created_at) FILTER (WHERE verified_at IS NOT NULL) as avg_verification_time
    FROM quick_task_completions;
END;
$$ LANGUAGE plpgsql;

-- Enable RLS on the quick_task_completions table
ALTER TABLE public.quick_task_completions ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for quick_task_completions
CREATE POLICY "Users can view their own completions" ON public.quick_task_completions
FOR SELECT USING (completed_by_user_id = auth.uid());

CREATE POLICY "Users can insert their own completions" ON public.quick_task_completions
FOR INSERT WITH CHECK (completed_by_user_id = auth.uid());

CREATE POLICY "Users can update their own completions" ON public.quick_task_completions
FOR UPDATE USING (completed_by_user_id = auth.uid());

-- Managers and verifiers can view all completions
CREATE POLICY "Managers can view all completions" ON public.quick_task_completions
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND user_type = 'global'
    )
);

-- Managers can verify completions
CREATE POLICY "Managers can verify completions" ON public.quick_task_completions
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND user_type = 'global'
    )
);