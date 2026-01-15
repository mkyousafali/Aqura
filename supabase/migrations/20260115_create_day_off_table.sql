-- Create day_off table for managing employee day-off records
CREATE TABLE IF NOT EXISTS day_off (
    id TEXT PRIMARY KEY,
    employee_id TEXT NOT NULL REFERENCES hr_employee_master(id) ON DELETE CASCADE,
    day_off_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_employee_day_off UNIQUE(employee_id, day_off_date)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_day_off_employee_id 
    ON day_off(employee_id);
CREATE INDEX IF NOT EXISTS idx_day_off_date 
    ON day_off(day_off_date);

-- Create trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_day_off_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS day_off_timestamp_trigger ON day_off;
CREATE TRIGGER day_off_timestamp_trigger
BEFORE UPDATE ON day_off
FOR EACH ROW
EXECUTE FUNCTION update_day_off_timestamp();
