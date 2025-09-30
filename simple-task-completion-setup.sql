-- Simplified task completion system setup
-- This version focuses only on essential database changes without storage policies

-- Add the completion_photo_url column to task_completions table
ALTER TABLE public.task_completions 
ADD COLUMN IF NOT EXISTS completion_photo_url TEXT NULL;

-- Remove the unique constraint that prevents multiple completions of the same task
-- This allows the same task to be assigned and completed multiple times
ALTER TABLE public.task_completions 
DROP CONSTRAINT IF EXISTS task_completions_task_id_completed_by_key;

-- Add comment for the new column
COMMENT ON COLUMN public.task_completions.completion_photo_url IS 'URL of the uploaded completion photo stored in completion-photos bucket';

-- Create index for photo URL lookups
CREATE INDEX IF NOT EXISTS idx_task_completions_photo_url 
    ON public.task_completions 
    USING btree (completion_photo_url) 
    TABLESPACE pg_default
    WHERE completion_photo_url IS NOT NULL;

-- Handle existing data that might violate the new constraint
UPDATE public.task_completions 
SET photo_uploaded_completed = false 
WHERE photo_uploaded_completed = true 
  AND completion_photo_url IS NULL;

-- Drop existing constraint if it exists, then recreate it
ALTER TABLE public.task_completions 
DROP CONSTRAINT IF EXISTS chk_photo_url_consistency;

ALTER TABLE public.task_completions 
ADD CONSTRAINT chk_photo_url_consistency 
CHECK (
    (photo_uploaded_completed = false OR completion_photo_url IS NOT NULL)
);

-- Update the view to include the new column
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
    tc.completion_photo_url,
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
LEFT JOIN public.branches b ON tc.completed_by_branch_id::text = b.id::text
ORDER BY tc.completed_at DESC;

-- Display completion message
SELECT 'Task completion system setup completed successfully!' as message;