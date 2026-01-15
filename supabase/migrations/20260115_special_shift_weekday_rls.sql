-- Create migration for special_shift_weekday table
-- This matches the existing table schema already created in the database

-- Note: The table special_shift_weekday already exists in your Supabase database
-- This migration serves as documentation of the schema

-- The table uses:
-- - id: TEXT PRIMARY KEY
-- - employee_id: TEXT (foreign key to hr_employee_master)
-- - weekday: INTEGER (0=Sunday, 1=Monday, ..., 6=Saturday)
-- - Unique constraint on (employee_id, weekday)

-- Enable RLS on special_shift_weekday table with permissive policies

-- Enable RLS (Row Level Security)
ALTER TABLE special_shift_weekday ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to special_shift_weekday" ON special_shift_weekday;

-- Simple permissive policy for all operations
CREATE POLICY "Allow all access to special_shift_weekday"
  ON special_shift_weekday
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON special_shift_weekday TO authenticated;
GRANT ALL ON special_shift_weekday TO service_role;
GRANT ALL ON special_shift_weekday TO anon;

-- Create or replace the timestamp update function
CREATE OR REPLACE FUNCTION update_special_shift_weekday_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
