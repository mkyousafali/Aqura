-- ============================================================
-- FINAL Product Discount Offer Migration
-- Drop existing offer_products table and recreate with correct schema
-- ============================================================

-- Step 1: Drop existing table (if exists)
DROP TABLE IF EXISTS public.offer_products CASCADE;

-- Step 2: Create new offer_products table with product discount schema
CREATE TABLE public.offer_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id INTEGER NOT NULL,
  product_id UUID NOT NULL,
  offer_qty INTEGER NOT NULL DEFAULT 1,
  offer_percentage DECIMAL(5,2) NULL,
  offer_price DECIMAL(10,2) NULL,
  max_uses INTEGER NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Foreign Keys
  CONSTRAINT offer_products_offer_id_fkey 
    FOREIGN KEY (offer_id) REFERENCES offers(id) ON DELETE CASCADE,
  CONSTRAINT offer_products_product_id_fkey 
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  
  -- Unique Constraint
  CONSTRAINT unique_offer_product UNIQUE(offer_id, product_id),
  
  -- Check Constraints
  CONSTRAINT valid_offer_qty CHECK (offer_qty > 0),
  CONSTRAINT valid_percentage CHECK (
    offer_percentage IS NULL OR (offer_percentage >= 0 AND offer_percentage <= 100)
  ),
  CONSTRAINT valid_offer_price CHECK (offer_price IS NULL OR offer_price >= 0),
  CONSTRAINT either_percentage_or_price CHECK (
    (offer_percentage IS NOT NULL AND offer_price IS NULL) OR
    (offer_percentage IS NULL AND offer_price IS NOT NULL)
  )
) TABLESPACE pg_default;

-- Step 3: Create indexes
CREATE INDEX idx_offer_products_offer_id 
  ON public.offer_products USING btree (offer_id) TABLESPACE pg_default;

CREATE INDEX idx_offer_products_product_id 
  ON public.offer_products USING btree (product_id) TABLESPACE pg_default;

CREATE INDEX idx_offer_products_active_lookup 
  ON public.offer_products USING btree (offer_id, product_id) TABLESPACE pg_default;

-- Step 4: Add comments
COMMENT ON TABLE public.offer_products IS 
  'Stores individual products in product discount offers with percentage or special price';

COMMENT ON COLUMN public.offer_products.offer_id IS 
  'Reference to parent offer';

COMMENT ON COLUMN public.offer_products.product_id IS 
  'Reference to product';

COMMENT ON COLUMN public.offer_products.offer_qty IS 
  'Quantity required for offer (e.g., 2 for "2 pieces for 39.95")';

COMMENT ON COLUMN public.offer_products.offer_percentage IS 
  'Percentage discount (e.g., 20.00 for 20% off) - NULL for special price offers';

COMMENT ON COLUMN public.offer_products.offer_price IS 
  'Special price for offer quantity (e.g., 39.95 for 2 pieces) - NULL for percentage offers';

COMMENT ON COLUMN public.offer_products.max_uses IS 
  'Maximum uses per product (NULL = unlimited)';

-- Step 5: Create trigger for updated_at (create function first if doesn't exist)
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER update_offer_products_updated_at
  BEFORE UPDATE ON public.offer_products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Step 6: Enable RLS
ALTER TABLE public.offer_products ENABLE ROW LEVEL SECURITY;

-- Step 7: Create RLS Policies
-- Allow public to view active offer products
DROP POLICY IF EXISTS "Public can view active offer products" ON public.offer_products;
CREATE POLICY "Public can view active offer products"
  ON public.offer_products
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

-- Allow authenticated users to manage all offer products
DROP POLICY IF EXISTS "Authenticated users can manage offer products" ON public.offer_products;
CREATE POLICY "Authenticated users can manage offer products"
  ON public.offer_products
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);

-- Step 8: Create helper function - Get product offers
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

COMMENT ON FUNCTION get_product_offers(UUID) IS 
  'Get all active product offers for a specific product, ordered by best savings';

-- Step 9: Create helper function - Validate product offer
CREATE OR REPLACE FUNCTION validate_product_offer(
  p_offer_id INTEGER,
  p_product_id UUID,
  p_quantity INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
  v_offer_qty INTEGER;
  v_is_active BOOLEAN;
  v_start_date TIMESTAMPTZ;
  v_end_date TIMESTAMPTZ;
BEGIN
  SELECT 
    op.offer_qty,
    o.is_active,
    o.start_date,
    o.end_date
  INTO 
    v_offer_qty,
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
  
  IF NOT v_is_active THEN
    RETURN FALSE;
  END IF;
  
  IF NOW() < v_start_date OR NOW() > v_end_date THEN
    RETURN FALSE;
  END IF;
  
  IF p_quantity < v_offer_qty THEN
    RETURN FALSE;
  END IF;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION validate_product_offer(INTEGER, UUID, INTEGER) IS 
  'Validate if product offer can be applied';

-- Step 10: Create helper function - Get products in active offers
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

COMMENT ON FUNCTION get_products_in_active_offers() IS 
  'Get all products in active product offers for admin filtering';

-- ============================================================
-- Migration Complete!
-- ============================================================
-- Next steps:
-- 1. Verify: SELECT * FROM offer_products;
-- 2. Test: node check-table-structure.js offer_products
-- 3. Implement save/load in ProductDiscountOfferWindow.svelte
-- ============================================================
