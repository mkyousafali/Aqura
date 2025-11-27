-- First, create the erp_connections table if it doesn't exist
CREATE TABLE IF NOT EXISTS erp_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    branch_name TEXT NOT NULL,
    server_ip TEXT NOT NULL,
    server_name TEXT,
    database_name TEXT NOT NULL,
    username TEXT NOT NULL,
    password TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(branch_id)
);

-- Enable RLS
ALTER TABLE erp_connections ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users to read ERP connections" ON erp_connections;
DROP POLICY IF EXISTS "Allow authenticated users to create ERP connections" ON erp_connections;
DROP POLICY IF EXISTS "Allow authenticated users to update ERP connections" ON erp_connections;
DROP POLICY IF EXISTS "Allow authenticated users to delete ERP connections" ON erp_connections;

-- Create RLS policies
CREATE POLICY "Allow authenticated users to read ERP connections"
    ON erp_connections FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to create ERP connections"
    ON erp_connections FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update ERP connections"
    ON erp_connections FOR UPDATE TO authenticated USING (true);

CREATE POLICY "Allow authenticated users to delete ERP connections"
    ON erp_connections FOR DELETE TO authenticated USING (true);

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION update_erp_connections_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and create trigger
DROP TRIGGER IF EXISTS update_erp_connections_updated_at ON erp_connections;
CREATE TRIGGER update_erp_connections_updated_at
    BEFORE UPDATE ON erp_connections
    FOR EACH ROW
    EXECUTE FUNCTION update_erp_connections_updated_at();

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_erp_connections_branch_id ON erp_connections(branch_id);
CREATE INDEX IF NOT EXISTS idx_erp_connections_is_active ON erp_connections(is_active);

-- Insert the default ERP configuration for branch ID 3
INSERT INTO erp_connections (
    branch_id,
    branch_name,
    server_ip,
    server_name,
    database_name,
    username,
    password,
    is_active
)
VALUES (
    3,
    (SELECT name_en FROM branches WHERE id = 3),
    '192.168.0.3',
    'WIN-D1D6ENB240A',
    'URBAN2_2025',
    'sa',
    'Polosys*123',
    true
)
ON CONFLICT (branch_id) DO UPDATE SET
    branch_name = EXCLUDED.branch_name,
    server_ip = EXCLUDED.server_ip,
    server_name = EXCLUDED.server_name,
    database_name = EXCLUDED.database_name,
    username = EXCLUDED.username,
    password = EXCLUDED.password,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

-- Verify the insert
SELECT 
    e.id,
    e.branch_name,
    e.server_ip,
    e.database_name,
    e.is_active,
    b.name_en as branch_english_name,
    b.name_ar as branch_arabic_name
FROM erp_connections e
JOIN branches b ON e.branch_id = b.id
ORDER BY e.created_at DESC;
