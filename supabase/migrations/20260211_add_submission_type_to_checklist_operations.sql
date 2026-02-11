-- Add submission type columns to hr_checklist_operations
ALTER TABLE hr_checklist_operations 
ADD COLUMN submission_type_en TEXT,
ADD COLUMN submission_type_ar TEXT;

-- Add comment for clarity
COMMENT ON COLUMN hr_checklist_operations.submission_type_en IS 'Submission type in English: POS, Daily, Weekly';
COMMENT ON COLUMN hr_checklist_operations.submission_type_ar IS 'Submission type in Arabic: POS, يومي, أسبوعي';

-- Create index for filtering by submission type
CREATE INDEX IF NOT EXISTS idx_checklist_operations_submission_type_en 
ON hr_checklist_operations (submission_type_en);
