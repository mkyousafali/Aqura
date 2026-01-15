-- Add working_hours column to regular_shift table
-- This column stores the calculated working hours based on shift times

ALTER TABLE regular_shift 
ADD COLUMN IF NOT EXISTS working_hours NUMERIC(5,2) DEFAULT 0;

-- Create function to calculate working hours
CREATE OR REPLACE FUNCTION calculate_working_hours()
RETURNS TRIGGER AS $$
DECLARE
  start_minutes INTEGER;
  end_minutes INTEGER;
  hours_diff NUMERIC;
BEGIN
  -- Convert times to minutes since midnight
  start_minutes := EXTRACT(HOUR FROM NEW.shift_start_time)::INTEGER * 60 + 
                   EXTRACT(MINUTE FROM NEW.shift_start_time)::INTEGER;
  end_minutes := EXTRACT(HOUR FROM NEW.shift_end_time)::INTEGER * 60 + 
                 EXTRACT(MINUTE FROM NEW.shift_end_time)::INTEGER;

  -- Calculate hours
  IF NEW.is_shift_overlapping_next_day THEN
    -- If shift overlaps to next day: (1440 - start_minutes + end_minutes) / 60
    hours_diff := (1440 - start_minutes + end_minutes)::NUMERIC / 60;
  ELSE
    -- If shift doesn't overlap: (end_minutes - start_minutes) / 60
    hours_diff := (end_minutes - start_minutes)::NUMERIC / 60;
  END IF;

  NEW.working_hours := ROUND(hours_diff, 2);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS calculate_working_hours_trigger ON regular_shift;

-- Create trigger to calculate working hours before insert or update
CREATE TRIGGER calculate_working_hours_trigger
BEFORE INSERT OR UPDATE ON regular_shift
FOR EACH ROW
EXECUTE FUNCTION calculate_working_hours();
