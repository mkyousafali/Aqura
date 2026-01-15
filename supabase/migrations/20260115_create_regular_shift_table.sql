-- Create regular_shift table for employee shift management
-- Stores regular shift details for each employee

CREATE TABLE IF NOT EXISTS regular_shift (
  id TEXT PRIMARY KEY REFERENCES hr_employee_master(id) ON DELETE CASCADE,
  shift_start_time TIME NOT NULL DEFAULT '09:00',
  shift_start_buffer NUMERIC(4,2) NOT NULL DEFAULT 0,
  shift_end_time TIME NOT NULL DEFAULT '17:00',
  shift_end_buffer NUMERIC(4,2) NOT NULL DEFAULT 0,
  is_shift_overlapping_next_day BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_regular_shift_created_at ON regular_shift(created_at);
CREATE INDEX IF NOT EXISTS idx_regular_shift_updated_at ON regular_shift(updated_at);

-- Create auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_regular_shift_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER regular_shift_timestamp_update
BEFORE UPDATE ON regular_shift
FOR EACH ROW
EXECUTE FUNCTION update_regular_shift_timestamp();
