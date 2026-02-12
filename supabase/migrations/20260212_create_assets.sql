-- Create assets table
-- Stores individual registered assets with auto-generated asset_id (group_code-sequential number)
-- Example: PPE-BLD-1, PPE-BLD-2, PPE-BLD-3 (unlimited)

CREATE TABLE IF NOT EXISTS assets (
    id SERIAL PRIMARY KEY,
    asset_id VARCHAR(30) NOT NULL UNIQUE,
    sub_category_id INTEGER NOT NULL REFERENCES asset_sub_categories(id) ON DELETE RESTRICT,
    asset_name_en VARCHAR(255) NOT NULL,
    asset_name_ar VARCHAR(255),
    purchase_date DATE,
    purchase_value DECIMAL(12,2) DEFAULT 0,
    branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
    invoice_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_assets_asset_id ON assets(asset_id);
CREATE INDEX IF NOT EXISTS idx_assets_sub_category_id ON assets(sub_category_id);
CREATE INDEX IF NOT EXISTS idx_assets_branch_id ON assets(branch_id);

-- Enable RLS
ALTER TABLE assets ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow all access to assets" ON assets;

-- Permissive policy
CREATE POLICY "Allow all access to assets"
    ON assets
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Grant access to all roles
GRANT ALL ON assets TO anon;
GRANT ALL ON assets TO authenticated;
GRANT ALL ON assets TO service_role;

-- Grant sequence access
GRANT USAGE, SELECT ON SEQUENCE assets_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE assets_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE assets_id_seq TO service_role;
