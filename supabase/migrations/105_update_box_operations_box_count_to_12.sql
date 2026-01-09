-- =============================================
-- MIGRATION: Update box_operations box_number constraint from 9 to 12
-- Created: 2026-01-09
-- Description: Update box_operations table to allow boxes 1-12
-- =============================================

-- Drop the existing constraint
ALTER TABLE box_operations
DROP CONSTRAINT IF EXISTS box_operations_box_number_check;

-- Add new constraint allowing 1-12
ALTER TABLE box_operations
ADD CONSTRAINT box_operations_box_number_check 
CHECK (box_number >= 1 AND box_number <= 12);
