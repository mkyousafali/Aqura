-- ============================================================
-- RLS Policies for Multi-Shift Tables
-- Permissive policies matching the app pattern (anon + authenticated + service_role)
-- ============================================================

-- ==================== multi_shift_regular ====================
ALTER TABLE multi_shift_regular ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to multi_shift_regular" ON multi_shift_regular;

CREATE POLICY "Allow all access to multi_shift_regular"
    ON multi_shift_regular
    FOR ALL
    USING (true)
    WITH CHECK (true);

GRANT ALL ON multi_shift_regular TO authenticated;
GRANT ALL ON multi_shift_regular TO service_role;
GRANT ALL ON multi_shift_regular TO anon;

-- Grant sequence access for SERIAL id
GRANT USAGE, SELECT ON SEQUENCE multi_shift_regular_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE multi_shift_regular_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE multi_shift_regular_id_seq TO anon;

-- ==================== multi_shift_date_wise ====================
ALTER TABLE multi_shift_date_wise ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to multi_shift_date_wise" ON multi_shift_date_wise;

CREATE POLICY "Allow all access to multi_shift_date_wise"
    ON multi_shift_date_wise
    FOR ALL
    USING (true)
    WITH CHECK (true);

GRANT ALL ON multi_shift_date_wise TO authenticated;
GRANT ALL ON multi_shift_date_wise TO service_role;
GRANT ALL ON multi_shift_date_wise TO anon;

GRANT USAGE, SELECT ON SEQUENCE multi_shift_date_wise_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE multi_shift_date_wise_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE multi_shift_date_wise_id_seq TO anon;

-- ==================== multi_shift_weekday ====================
ALTER TABLE multi_shift_weekday ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to multi_shift_weekday" ON multi_shift_weekday;

CREATE POLICY "Allow all access to multi_shift_weekday"
    ON multi_shift_weekday
    FOR ALL
    USING (true)
    WITH CHECK (true);

GRANT ALL ON multi_shift_weekday TO authenticated;
GRANT ALL ON multi_shift_weekday TO service_role;
GRANT ALL ON multi_shift_weekday TO anon;

GRANT USAGE, SELECT ON SEQUENCE multi_shift_weekday_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE multi_shift_weekday_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE multi_shift_weekday_id_seq TO anon;
