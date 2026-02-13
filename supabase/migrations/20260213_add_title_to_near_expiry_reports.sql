-- Add title column to near_expiry_reports table
ALTER TABLE near_expiry_reports ADD COLUMN IF NOT EXISTS title TEXT;
