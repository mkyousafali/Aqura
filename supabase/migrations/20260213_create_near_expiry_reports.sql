-- Near Expiry Reports table
-- Stores reports of products nearing their expiry date
CREATE TABLE IF NOT EXISTS near_expiry_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_user_id UUID NOT NULL REFERENCES users(id),
    branch_id INTEGER REFERENCES branches(id),
    target_user_id UUID REFERENCES users(id),
    title TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'resolved', 'dismissed')),
    items JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_near_expiry_reports_reporter ON near_expiry_reports(reporter_user_id);
CREATE INDEX IF NOT EXISTS idx_near_expiry_reports_branch ON near_expiry_reports(branch_id);
CREATE INDEX IF NOT EXISTS idx_near_expiry_reports_target ON near_expiry_reports(target_user_id);
CREATE INDEX IF NOT EXISTS idx_near_expiry_reports_status ON near_expiry_reports(status);
CREATE INDEX IF NOT EXISTS idx_near_expiry_reports_created ON near_expiry_reports(created_at DESC);

-- Enable RLS
ALTER TABLE near_expiry_reports ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS "Allow all access to near_expiry_reports" ON near_expiry_reports;

-- Simple permissive policy matching app pattern
CREATE POLICY "Allow all access to near_expiry_reports"
    ON near_expiry_reports
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON near_expiry_reports TO authenticated;
GRANT ALL ON near_expiry_reports TO service_role;
GRANT ALL ON near_expiry_reports TO anon;

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_near_expiry_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_near_expiry_reports_updated_at
    BEFORE UPDATE ON near_expiry_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_near_expiry_reports_updated_at();
