-- Migration: Add is_active column to expense_requisitions
-- Date: 2025-10-29
-- Purpose: Allow deactivation of requisitions without deletion

-- Add is_active column with default true
ALTER TABLE expense_requisitions
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true NOT NULL;

-- Add comment to document the column
COMMENT ON COLUMN expense_requisitions.is_active IS 'Indicates if the requisition is active. Deactivated requisitions are excluded from filters and scheduling.';

-- Create index for faster queries on active requisitions
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_is_active 
ON expense_requisitions(is_active) 
WHERE is_active = true;

-- Create index for combined queries (status + is_active)
CREATE INDEX IF NOT EXISTS idx_expense_requisitions_status_active 
ON expense_requisitions(status, is_active);

-- Update existing records to be active
UPDATE expense_requisitions 
SET is_active = true 
WHERE is_active IS NULL;

-- Migration completed successfully
