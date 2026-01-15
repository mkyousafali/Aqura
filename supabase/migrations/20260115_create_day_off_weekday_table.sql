-- Create day_off_weekday table for recurring day offs
CREATE TABLE day_off_weekday (
    id TEXT PRIMARY KEY,
    employee_id TEXT NOT NULL REFERENCES hr_employee_master(id) ON DELETE CASCADE,
    weekday INTEGER NOT NULL CHECK (weekday >= 0 AND weekday <= 6),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_employee_weekday_dayoff UNIQUE(employee_id, weekday)
);

-- Create indexes for better query performance
CREATE INDEX idx_day_off_weekday_employee_id ON day_off_weekday(employee_id);
CREATE INDEX idx_day_off_weekday_weekday ON day_off_weekday(weekday);

-- Create trigger to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_day_off_weekday_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER day_off_weekday_updated_at_trigger
BEFORE UPDATE ON day_off_weekday
FOR EACH ROW
EXECUTE FUNCTION update_day_off_weekday_updated_at();
