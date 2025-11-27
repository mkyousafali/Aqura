-- Create erp_daily_sales table for synced sales data
CREATE TABLE IF NOT EXISTS erp_daily_sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id BIGINT NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    sale_date DATE NOT NULL,
    total_bills INTEGER DEFAULT 0,
    gross_amount DECIMAL(18,2) DEFAULT 0,
    tax_amount DECIMAL(18,2) DEFAULT 0,
    discount_amount DECIMAL(18,2) DEFAULT 0,
    total_returns INTEGER DEFAULT 0,
    return_amount DECIMAL(18,2) DEFAULT 0,
    return_tax DECIMAL(18,2) DEFAULT 0,
    net_bills INTEGER DEFAULT 0,
    net_amount DECIMAL(18,2) DEFAULT 0,
    net_tax DECIMAL(18,2) DEFAULT 0,
    last_sync_at TIMESTAMPTZ,
    synced_by_device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(branch_id, sale_date)
);

-- Enable RLS
ALTER TABLE erp_daily_sales ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow authenticated users to read sales data" ON erp_daily_sales;
DROP POLICY IF EXISTS "Allow service role to manage sales data" ON erp_daily_sales;

-- Create RLS policies
CREATE POLICY "Allow authenticated users to read sales data"
    ON erp_daily_sales FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow service role to manage sales data"
    ON erp_daily_sales FOR ALL TO service_role USING (true);

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION update_erp_daily_sales_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and create trigger
DROP TRIGGER IF EXISTS update_erp_daily_sales_updated_at ON erp_daily_sales;
CREATE TRIGGER update_erp_daily_sales_updated_at
    BEFORE UPDATE ON erp_daily_sales
    FOR EACH ROW
    EXECUTE FUNCTION update_erp_daily_sales_updated_at();

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_erp_daily_sales_branch_id ON erp_daily_sales(branch_id);
CREATE INDEX IF NOT EXISTS idx_erp_daily_sales_sale_date ON erp_daily_sales(sale_date);
CREATE INDEX IF NOT EXISTS idx_erp_daily_sales_branch_date ON erp_daily_sales(branch_id, sale_date);

-- Verify table
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'erp_daily_sales'
ORDER BY ordinal_position;
