-- Create erp_synced_products table
-- Stores product barcodes synced from ERP SQL Server with unit details

CREATE TABLE IF NOT EXISTS erp_synced_products (
  id SERIAL PRIMARY KEY,
  barcode VARCHAR(50) NOT NULL UNIQUE,
  auto_barcode VARCHAR(50),
  parent_barcode VARCHAR(50),
  product_name_en VARCHAR(500),
  product_name_ar VARCHAR(500),
  unit_name VARCHAR(100),
  unit_qty DECIMAL(18,6) DEFAULT 1,
  is_base_unit BOOLEAN DEFAULT false,
  synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_barcode ON erp_synced_products(barcode);
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_parent_barcode ON erp_synced_products(parent_barcode);
CREATE INDEX IF NOT EXISTS idx_erp_synced_products_product_name_en ON erp_synced_products(product_name_en);

-- Enable RLS
ALTER TABLE erp_synced_products ENABLE ROW LEVEL SECURITY;

-- Simple permissive policy
CREATE POLICY "Allow all access to erp_synced_products"
  ON erp_synced_products
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles
GRANT ALL ON erp_synced_products TO authenticated;
GRANT ALL ON erp_synced_products TO service_role;
GRANT ALL ON erp_synced_products TO anon;

-- Grant sequence access for SERIAL
GRANT USAGE, SELECT ON SEQUENCE erp_synced_products_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE erp_synced_products_id_seq TO service_role;
GRANT USAGE, SELECT ON SEQUENCE erp_synced_products_id_seq TO anon;
