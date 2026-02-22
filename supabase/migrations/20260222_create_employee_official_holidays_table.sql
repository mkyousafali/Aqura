-- Create employee_official_holidays junction table
-- Links specific employees to official holidays (not all employees get every holiday)
CREATE TABLE IF NOT EXISTS employee_official_holidays (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    employee_id TEXT NOT NULL REFERENCES hr_employee_master(id) ON DELETE CASCADE,
    official_holiday_id TEXT NOT NULL REFERENCES official_holidays(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_employee_official_holiday UNIQUE(employee_id, official_holiday_id)
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_eoh_employee_id ON employee_official_holidays(employee_id);
CREATE INDEX IF NOT EXISTS idx_eoh_holiday_id ON employee_official_holidays(official_holiday_id);

-- Enable RLS
ALTER TABLE employee_official_holidays ENABLE ROW LEVEL SECURITY;

-- Permissive policy
DROP POLICY IF EXISTS "Allow all operations on employee_official_holidays" ON employee_official_holidays;
CREATE POLICY "Allow all operations on employee_official_holidays" ON employee_official_holidays
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant permissions to all roles
GRANT ALL ON employee_official_holidays TO anon, authenticated, service_role;
