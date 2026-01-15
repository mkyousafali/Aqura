-- Enable RLS on day_off table
ALTER TABLE day_off ENABLE ROW LEVEL SECURITY;

-- Create a permissive RLS policy for all authenticated users
CREATE POLICY "Allow all operations on day_off" ON day_off
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant permissions to all roles
GRANT ALL ON day_off TO anon, authenticated, service_role;
