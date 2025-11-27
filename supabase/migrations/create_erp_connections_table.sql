-- Create erp_connections table to store ERP database configurations

CREATE TABLE IF NOT EXISTS erp_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
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

-- Add RLS policies
ALTER TABLE erp_connections ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read all ERP connections
CREATE POLICY "Allow authenticated users to read ERP connections"
    ON erp_connections
    FOR SELECT
    TO authenticated
    USING (true);

-- Policy: Allow authenticated users to insert ERP connections
CREATE POLICY "Allow authenticated users to create ERP connections"
    ON erp_connections
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Policy: Allow authenticated users to update ERP connections
CREATE POLICY "Allow authenticated users to update ERP connections"
    ON erp_connections
    FOR UPDATE
    TO authenticated
    USING (true);

-- Policy: Allow authenticated users to delete ERP connections
CREATE POLICY "Allow authenticated users to delete ERP connections"
    ON erp_connections
    FOR DELETE
    TO authenticated
    USING (true);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_erp_connections_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_erp_connections_updated_at
    BEFORE UPDATE ON erp_connections
    FOR EACH ROW
    EXECUTE FUNCTION update_erp_connections_updated_at();

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_erp_connections_branch_id ON erp_connections(branch_id);
CREATE INDEX IF NOT EXISTS idx_erp_connections_is_active ON erp_connections(is_active);

COMMENT ON TABLE erp_connections IS 'Stores ERP database connection configurations for each branch';
