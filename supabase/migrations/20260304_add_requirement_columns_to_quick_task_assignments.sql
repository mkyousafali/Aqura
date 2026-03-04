-- Add requirement columns to quick_task_assignments table
-- These columns control what must be completed for task completion

ALTER TABLE quick_task_assignments
ADD COLUMN IF NOT EXISTS require_task_finished BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS require_photo_upload BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS require_erp_reference BOOLEAN DEFAULT false;

-- Add comments for clarity
COMMENT ON COLUMN quick_task_assignments.require_task_finished IS 'Whether task completion checkbox is required';
COMMENT ON COLUMN quick_task_assignments.require_photo_upload IS 'Whether photo upload is required for task completion';
COMMENT ON COLUMN quick_task_assignments.require_erp_reference IS 'Whether ERP reference number is required for task completion';

-- Create index on status for faster lookups
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_status ON quick_task_assignments(status);
CREATE INDEX IF NOT EXISTS idx_quick_task_assignments_assignment_id_status ON quick_task_assignments(quick_task_id, status);
