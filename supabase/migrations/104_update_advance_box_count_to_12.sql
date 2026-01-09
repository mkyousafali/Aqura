-- =============================================
-- MIGRATION: Update POS Advance Manager box count from 9 to 12
-- Created: 2026-01-09
-- Description: Update denomination_records box_number constraint
--              to allow boxes 1-12 instead of 1-9
-- =============================================

-- Drop the existing constraint
ALTER TABLE denomination_records
DROP CONSTRAINT IF EXISTS denomination_records_box_number_check;

-- Add new constraint allowing 1-12
ALTER TABLE denomination_records
ADD CONSTRAINT denomination_records_box_number_check 
CHECK (box_number IS NULL OR (box_number >= 1 AND box_number <= 12));

-- Update comment to reflect new range
COMMENT ON COLUMN denomination_records.box_number IS 'Box or card number (1-12 for advance boxes, 1-6 for collection boxes, 1-6 for paid/received, null for main)';
