-- =============================================
-- BOX OPERATIONS - FIX STATUS CHECK CONSTRAINT
-- Created: 2026-01-06
-- Description: Ensure pending_close status is allowed in check constraint
-- =============================================

-- Drop the existing constraint if it exists with wrong values
ALTER TABLE box_operations DROP CONSTRAINT IF EXISTS box_operations_status_check;

-- Add the correct constraint with all status values including pending_close
ALTER TABLE box_operations ADD CONSTRAINT box_operations_status_check 
    CHECK (status IN ('in_use', 'pending_close', 'completed', 'cancelled'));

-- Comment
COMMENT ON TABLE box_operations IS 'Tracks POS cash box operations and counter check sessions';
COMMENT ON COLUMN box_operations.status IS 'Operation status: in_use (active), pending_close (waiting for final close), completed, or cancelled';
