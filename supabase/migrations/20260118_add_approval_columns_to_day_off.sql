-- Add approval-related columns to day_off table
ALTER TABLE day_off
ADD COLUMN IF NOT EXISTS day_off_reason_id VARCHAR(50) REFERENCES day_off_reasons(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS approval_status VARCHAR(50) DEFAULT 'pending' CHECK (approval_status IN ('pending', 'sent_for_approval', 'approved', 'rejected')),
ADD COLUMN IF NOT EXISTS approval_requested_by UUID REFERENCES users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS approval_requested_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS approval_approved_by UUID REFERENCES users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS approval_approved_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS approval_notes TEXT,
ADD COLUMN IF NOT EXISTS document_url TEXT,
ADD COLUMN IF NOT EXISTS document_uploaded_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS is_deductible_on_salary BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Create index for approval status queries
CREATE INDEX IF NOT EXISTS idx_day_off_approval_status ON day_off(approval_status);
CREATE INDEX IF NOT EXISTS idx_day_off_approval_requested_by ON day_off(approval_requested_by);
CREATE INDEX IF NOT EXISTS idx_day_off_reason_id ON day_off(day_off_reason_id);

-- Create trigger to update updated_at on approval status change
DROP TRIGGER IF EXISTS day_off_timestamp_trigger ON day_off;
CREATE TRIGGER day_off_timestamp_trigger
BEFORE UPDATE ON day_off
FOR EACH ROW
EXECUTE FUNCTION update_day_off_timestamp();
