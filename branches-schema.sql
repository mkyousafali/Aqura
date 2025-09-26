-- Branches Table Schema
-- This table stores branch information with multilingual support

CREATE TABLE branches (
    id BIGSERIAL PRIMARY KEY,
    
    -- Branch Names (Multilingual)
    name_en VARCHAR(255) NOT NULL,
    name_ar VARCHAR(255) NOT NULL,
    
    -- Location Names (Multilingual)
    location_en VARCHAR(500) NOT NULL,
    location_ar VARCHAR(500) NOT NULL,
    

    
    -- Status and metadata
    is_active BOOLEAN DEFAULT true,
    is_main_branch BOOLEAN DEFAULT false,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by BIGINT,
    updated_by BIGINT
);

-- Create indexes for better performance
CREATE INDEX idx_branches_name_en ON branches(name_en);
CREATE INDEX idx_branches_name_ar ON branches(name_ar);
CREATE INDEX idx_branches_active ON branches(is_active);
CREATE INDEX idx_branches_main ON branches(is_main_branch);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_branches_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_branches_updated_at
    BEFORE UPDATE ON branches
    FOR EACH ROW
    EXECUTE FUNCTION update_branches_updated_at();

-- Add RLS (Row Level Security) policies if needed
-- Temporarily disable RLS for development
-- ALTER TABLE branches ENABLE ROW LEVEL SECURITY;

-- Simple policies that allow all operations for development
-- You can re-enable and customize these policies when authentication is implemented

-- Policy to allow all users to view branches
-- CREATE POLICY "Allow all users to view branches" ON branches
--     FOR SELECT
--     USING (true);

-- Policy to allow all users to insert branches (for development)
-- CREATE POLICY "Allow all users to insert branches" ON branches
--     FOR INSERT
--     WITH CHECK (true);

-- Policy to allow all users to update branches (for development)
-- CREATE POLICY "Allow all users to update branches" ON branches
--     FOR UPDATE
--     USING (true)
--     WITH CHECK (true);

-- Policy to allow all users to delete branches (for development)
-- CREATE POLICY "Allow all users to delete branches" ON branches
--     FOR DELETE
--     USING (true);

-- Insert initial branch data
INSERT INTO branches (id, name_en, name_ar, location_en, location_ar, is_active, is_main_branch) VALUES
(1, 'Urban Market (AB)', 'ايربن ماركت (AB)', 'Abu Arish', 'أبو عريش', true, true),
(2, 'Ali Hassan bin Mohammed Sahli Trading Grocery Store', 'تموينات علي حسن بن محمد سهلي للتجارة', 'Ahad al Masarah', 'أحد المسارحة', true, false),
(3, 'Urban Market (AR)', 'ايربن ماركت (AR)', 'Al-Aridhah', 'العارضة', true, false);

-- Reset the sequence to start from the next available ID
SELECT setval('branches_id_seq', (SELECT MAX(id) FROM branches));