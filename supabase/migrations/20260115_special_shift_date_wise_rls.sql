-- Enable RLS on special_shift_date_wise table
ALTER TABLE special_shift_date_wise ENABLE ROW LEVEL SECURITY;

-- Create a permissive RLS policy for all authenticated users
CREATE POLICY "Allow all operations on special_shift_date_wise" ON special_shift_date_wise
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant permissions to all roles
GRANT ALL ON special_shift_date_wise TO anon, authenticated, service_role;
