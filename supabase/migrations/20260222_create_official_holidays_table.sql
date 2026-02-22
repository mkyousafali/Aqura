-- Create official_holidays table for managing company-wide official/public holidays
CREATE TABLE IF NOT EXISTS official_holidays (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    holiday_date DATE NOT NULL,
    name_en TEXT NOT NULL DEFAULT '',
    name_ar TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_official_holiday_date UNIQUE(holiday_date)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_official_holidays_date 
    ON official_holidays(holiday_date);

-- Create trigger to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_official_holidays_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS official_holidays_timestamp_trigger ON official_holidays;
CREATE TRIGGER official_holidays_timestamp_trigger
BEFORE UPDATE ON official_holidays
FOR EACH ROW
EXECUTE FUNCTION update_official_holidays_timestamp();

-- Enable RLS on official_holidays table
ALTER TABLE official_holidays ENABLE ROW LEVEL SECURITY;

-- Create a permissive RLS policy for all authenticated users
CREATE POLICY "Allow all operations on official_holidays" ON official_holidays
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant permissions to all roles
GRANT ALL ON official_holidays TO anon, authenticated, service_role;
