-- Create special_shift_date_wise table for date-specific shift configurations
CREATE TABLE IF NOT EXISTS special_shift_date_wise (
    id TEXT PRIMARY KEY,
    employee_id TEXT NOT NULL REFERENCES hr_employee_master(id) ON DELETE CASCADE,
    shift_date DATE NOT NULL,
    shift_start_time TIME NOT NULL DEFAULT '09:00',
    shift_start_buffer NUMERIC(4, 2) DEFAULT 0,
    shift_end_time TIME NOT NULL DEFAULT '17:00',
    shift_end_buffer NUMERIC(4, 2) DEFAULT 0,
    is_shift_overlapping_next_day BOOLEAN DEFAULT FALSE,
    working_hours NUMERIC(5, 2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_employee_date UNIQUE(employee_id, shift_date)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_special_shift_date_wise_employee_id 
    ON special_shift_date_wise(employee_id);
CREATE INDEX IF NOT EXISTS idx_special_shift_date_wise_date 
    ON special_shift_date_wise(shift_date);

-- Create trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_special_shift_date_wise_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS special_shift_date_wise_timestamp_trigger ON special_shift_date_wise;
CREATE TRIGGER special_shift_date_wise_timestamp_trigger
BEFORE UPDATE ON special_shift_date_wise
FOR EACH ROW
EXECUTE FUNCTION update_special_shift_date_wise_timestamp();
