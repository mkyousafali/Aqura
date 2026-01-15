-- Enable RLS on day_off_weekday table
ALTER TABLE day_off_weekday ENABLE ROW LEVEL SECURITY;

-- Create a permissive RLS policy for all authenticated users
CREATE POLICY "Allow all operations on day_off_weekday" ON day_off_weekday
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant permissions to all roles
GRANT ALL ON day_off_weekday TO anon, authenticated, service_role;
