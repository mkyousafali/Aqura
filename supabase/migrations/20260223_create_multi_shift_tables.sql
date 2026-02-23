-- ============================================================
-- Multi-Shift Tables
-- Allows employees to have MULTIPLE shifts per day
-- Three categories: Regular, Date-wise, Weekday-wise
-- ============================================================

-- 1) multi_shift_regular: recurring multi-shifts (no date constraint)
CREATE TABLE IF NOT EXISTS multi_shift_regular (
    id SERIAL PRIMARY KEY,
    employee_id TEXT NOT NULL REFERENCES hr_employee_master(id) ON DELETE CASCADE,
    shift_start_time TIME NOT NULL DEFAULT '09:00',
    shift_start_buffer NUMERIC(4,2) NOT NULL DEFAULT 0,
    shift_end_time TIME NOT NULL DEFAULT '17:00',
    shift_end_buffer NUMERIC(4,2) NOT NULL DEFAULT 0,
    is_shift_overlapping_next_day BOOLEAN NOT NULL DEFAULT false,
    working_hours NUMERIC(5,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_multi_shift_regular_employee_id ON multi_shift_regular(employee_id);

-- 2) multi_shift_date_wise: multi-shifts for specific date ranges
CREATE TABLE IF NOT EXISTS multi_shift_date_wise (
    id SERIAL PRIMARY KEY,
    employee_id TEXT NOT NULL REFERENCES hr_employee_master(id) ON DELETE CASCADE,
    date_from DATE NOT NULL,
    date_to DATE NOT NULL,
    shift_start_time TIME NOT NULL DEFAULT '09:00',
    shift_start_buffer NUMERIC(4,2) NOT NULL DEFAULT 0,
    shift_end_time TIME NOT NULL DEFAULT '17:00',
    shift_end_buffer NUMERIC(4,2) NOT NULL DEFAULT 0,
    is_shift_overlapping_next_day BOOLEAN NOT NULL DEFAULT false,
    working_hours NUMERIC(5,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT multi_shift_date_wise_date_check CHECK (date_from <= date_to)
);

CREATE INDEX IF NOT EXISTS idx_multi_shift_date_wise_employee_id ON multi_shift_date_wise(employee_id);
CREATE INDEX IF NOT EXISTS idx_multi_shift_date_wise_dates ON multi_shift_date_wise(date_from, date_to);

-- 3) multi_shift_weekday: multi-shifts for specific weekdays
CREATE TABLE IF NOT EXISTS multi_shift_weekday (
    id SERIAL PRIMARY KEY,
    employee_id TEXT NOT NULL REFERENCES hr_employee_master(id) ON DELETE CASCADE,
    weekday INTEGER NOT NULL,
    shift_start_time TIME NOT NULL DEFAULT '09:00',
    shift_start_buffer NUMERIC(4,2) NOT NULL DEFAULT 0,
    shift_end_time TIME NOT NULL DEFAULT '17:00',
    shift_end_buffer NUMERIC(4,2) NOT NULL DEFAULT 0,
    is_shift_overlapping_next_day BOOLEAN NOT NULL DEFAULT false,
    working_hours NUMERIC(5,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT multi_shift_weekday_weekday_check CHECK (weekday >= 0 AND weekday <= 6)
);

CREATE INDEX IF NOT EXISTS idx_multi_shift_weekday_employee_id ON multi_shift_weekday(employee_id);
CREATE INDEX IF NOT EXISTS idx_multi_shift_weekday_weekday ON multi_shift_weekday(weekday);

-- Auto-update triggers for updated_at
CREATE OR REPLACE FUNCTION update_multi_shift_regular_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER multi_shift_regular_timestamp_update
BEFORE UPDATE ON multi_shift_regular
FOR EACH ROW EXECUTE FUNCTION update_multi_shift_regular_timestamp();

CREATE OR REPLACE FUNCTION update_multi_shift_date_wise_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER multi_shift_date_wise_timestamp_update
BEFORE UPDATE ON multi_shift_date_wise
FOR EACH ROW EXECUTE FUNCTION update_multi_shift_date_wise_timestamp();

CREATE OR REPLACE FUNCTION update_multi_shift_weekday_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER multi_shift_weekday_timestamp_update
BEFORE UPDATE ON multi_shift_weekday
FOR EACH ROW EXECUTE FUNCTION update_multi_shift_weekday_timestamp();
