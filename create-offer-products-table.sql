-- ============================================================
-- Product Discount Offer Migration
-- Create offer_products table for individual product offers
-- ============================================================

-- Step 1: Create offer_products table
CREATE TABLE IF NOT EXISTS offer_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id INTEGER NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  offer_qty INTEGER NOT NULL DEFAULT 1,
  offer_percentage DECIMAL(5,2), -- For percentage offers (e.g., 20.00)
  offer_price DECIMAL(10,2), -- For special price offers (e.g., 39.95)
  max_uses INTEGER, -- Per-product usage limit (NULL = unlimited)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT unique_offer_product UNIQUE(offer_id, product_id),
  CONSTRAINT valid_offer_qty CHECK (offer_qty > 0),
  CONSTRAINT valid_percentage CHECK (offer_percentage IS NULL OR (offer_percentage >= 0 AND offer_percentage <= 100)),
  CONSTRAINT valid_offer_price CHECK (offer_price IS NULL OR offer_price >= 0),
  CONSTRAINT either_percentage_or_price CHECK (
    (offer_percentage IS NOT NULL AND offer_price IS NULL) OR
    (offer_percentage IS NULL AND offer_price IS NOT NULL)
  )
);

-- Step 2: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_offer_products_offer_id ON offer_products(offer_id);
CREATE INDEX IF NOT EXISTS idx_offer_products_product_id ON offer_products(product_id);
CREATE INDEX IF NOT EXISTS idx_offer_products_active_lookup ON offer_products(offer_id, product_id);

-- Step 3: Create trigger for updated_at
CREATE OR REPLACE TRIGGER update_offer_products_updated_at
  BEFORE UPDATE ON offer_products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Step 4: Add table and column comments
COMMENT ON TABLE offer_products IS 'Stores individual products included in product discount offers with their specific pricing (percentage or special price)';
COMMENT ON COLUMN offer_products.offer_id IS 'Reference to the parent offer in offers table';
COMMENT ON COLUMN offer_products.product_id IS 'Reference to the product being offered';
COMMENT ON COLUMN offer_products.offer_qty IS 'Quantity of product required for this offer (e.g., 2 for "2 pieces for 39.95")';
COMMENT ON COLUMN offer_products.offer_percentage IS 'Percentage discount (used for percentage offer type only, e.g., 20.00 for 20% off)';
COMMENT ON COLUMN offer_products.offer_price IS 'Special price for the offer quantity (used for special_price offer type only, e.g., 39.95 for 2 pieces)';
COMMENT ON COLUMN offer_products.max_uses IS 'Maximum number of times this specific product offer can be used (NULL = unlimited)';

-- Step 5: Enable Row Level Security
ALTER TABLE offer_products ENABLE ROW LEVEL SECURITY;

-- Step 6: Create RLS policies
-- Policy 1: Allow public to view active offer products
DROP POLICY IF EXISTS "Public can view active offer products" ON offer_products;
CREATE POLICY "Public can view active offer products"
  ON offer_products
  FOR SELECT
  TO public
  USING (
    offer_id IN (
      SELECT id FROM offers 
      WHERE is_active = true 
        AND start_date <= NOW() 
        AND end_date >= NOW()
    )
  );

-- Policy 2: Allow authenticated users to manage offer products
DROP POLICY IF EXISTS "Authenticated users can manage offer products" ON offer_products;
CREATE POLICY "Authenticated users can manage offer products"
  ON offer_products
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Step 7: Create helper function - Get product offers
CREATE OR REPLACE FUNCTION get_product_offers(p_product_id UUID)
RETURNS TABLE (
  offer_id INTEGER,
  offer_name_en TEXT,
  offer_name_ar TEXT,
  offer_type TEXT,
  discount_type TEXT,
  offer_qty INTEGER,
  offer_percentage DECIMAL,
  offer_price DECIMAL,
  original_price DECIMAL,
  savings DECIMAL,
  end_date TIMESTAMPTZ,
  service_type TEXT,
  branch_id INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.id AS offer_id,
    o.name_en AS offer_name_en,
    o.name_ar AS offer_name_ar,
    o.type AS offer_type,
    o.discount_type,
    op.offer_qty,
    op.offer_percentage,
    op.offer_price,
    p.sale_price AS original_price,
    CASE 
      WHEN op.offer_percentage IS NOT NULL THEN 
        (p.sale_price * op.offer_qty) - ((p.sale_price * op.offer_qty) * (1 - op.offer_percentage / 100))
      WHEN op.offer_price IS NOT NULL THEN 
        (p.sale_price * op.offer_qty) - op.offer_price
      ELSE 0
    END AS savings,
    o.end_date,
    o.service_type,
    o.branch_id
  FROM offers o
  INNER JOIN offer_products op ON o.id = op.offer_id
  INNER JOIN products p ON op.product_id = p.id
  WHERE op.product_id = p_product_id
    AND o.is_active = true
    AND o.type = 'product'
    AND o.start_date <= NOW()
    AND o.end_date >= NOW()
  ORDER BY savings DESC;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_product_offers(UUID) IS 'Get all active product offers for a specific product, ordered by savings (best offer first)';

-- Step 8: Create helper function - Validate product offer
CREATE OR REPLACE FUNCTION validate_product_offer(
  p_offer_id INTEGER,
  p_product_id UUID,
  p_quantity INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
  v_offer_qty INTEGER;
  v_max_uses INTEGER;
  v_is_active BOOLEAN;
  v_start_date TIMESTAMPTZ;
  v_end_date TIMESTAMPTZ;
BEGIN
  -- Get offer details
  SELECT 
    op.offer_qty, 
    op.max_uses,
    o.is_active,
    o.start_date,
    o.end_date
  INTO 
    v_offer_qty, 
    v_max_uses,
    v_is_active,
    v_start_date,
    v_end_date
  FROM offer_products op
  INNER JOIN offers o ON op.offer_id = o.id
  WHERE op.offer_id = p_offer_id 
    AND op.product_id = p_product_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Check if offer is active
  IF NOT v_is_active THEN
    RETURN FALSE;
  END IF;
  
  -- Check if offer is within valid date range
  IF NOW() < v_start_date OR NOW() > v_end_date THEN
    RETURN FALSE;
  END IF;
  
  -- Check if quantity matches offer requirement
  IF p_quantity < v_offer_qty THEN
    RETURN FALSE;
  END IF;
  
  -- TODO: Check usage limits against usage_logs table when implemented
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION validate_product_offer(INTEGER, UUID, INTEGER) IS 'Validate if a product offer can be applied based on quantity, active status, and date range';

-- Step 9: Create function - Get all products in active offers (for filtering)
CREATE OR REPLACE FUNCTION get_products_in_active_offers()
RETURNS TABLE (
  product_id UUID,
  offer_id INTEGER,
  offer_name_en TEXT,
  offer_name_ar TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    op.product_id,
    o.id AS offer_id,
    o.name_en AS offer_name_en,
    o.name_ar AS offer_name_ar
  FROM offer_products op
  INNER JOIN offers o ON op.offer_id = o.id
  WHERE o.is_active = true
    AND o.type = 'product'
    AND o.start_date <= NOW()
    AND o.end_date >= NOW();
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_products_in_active_offers() IS 'Get list of all products that are currently in active product offers (useful for admin filtering)';

-- Step 10: Verification query
DO $$
BEGIN
  RAISE NOTICE 'Migration completed successfully!';
  RAISE NOTICE 'Table created: offer_products';
  RAISE NOTICE 'Indexes created: 3';
  RAISE NOTICE 'RLS policies created: 2';
  RAISE NOTICE 'Helper functions created: 3';
  RAISE NOTICE '';
  RAISE NOTICE 'Next steps:';
  RAISE NOTICE '1. Verify table structure: node check-table-structure.js offer_products';
  RAISE NOTICE '2. Test with sample data';
  RAISE NOTICE '3. Implement save/load functionality in frontend';
END $$;
