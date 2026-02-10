-- Add max_points column to hr_checklist_operations table
-- This stores the total possible points from all questions

ALTER TABLE hr_checklist_operations ADD COLUMN IF NOT EXISTS max_points INTEGER NOT NULL DEFAULT 0;

-- Add comment
COMMENT ON COLUMN hr_checklist_operations.max_points IS 'Total possible points from all questions in the checklist';
