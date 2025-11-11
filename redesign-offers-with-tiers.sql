-- ============================================
-- Redesign Offers System - Remove Priority, Add Cart Tiers
-- ============================================
-- Changes:
-- 1. Remove priority field from offers table
-- 2. Add offer_cart_tiers table for tiered cart discounts
-- 3. Simplify offer types (only product and cart)
-- ============================================

-- Step 1: Remove priority column from offers table
ALTER TABLE offers DROP COLUMN IF EXISTS priority;

-- Step 2: Remove allow_stacking (not needed with new design)
ALTER TABLE offers DROP COLUMN IF EXISTS allow_stacking;

-- Step 2.5: Modify discount_value constraint to allow 0 for cart offers with tiers
ALTER TABLE offers DROP CONSTRAINT IF EXISTS offers_discount_value_check;
ALTER TABLE offers ADD CONSTRAINT offers_discount_value_check 
CHECK (discount_value >= 0);

-- Step 3: Create new cart discount tiers table
CREATE TABLE IF NOT EXISTS offer_cart_tiers (
    id SERIAL PRIMARY KEY,
    offer_id INTEGER NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
    tier_number INTEGER NOT NULL CHECK (tier_number BETWEEN 1 AND 6),
    min_amount DECIMAL(10,2) NOT NULL CHECK (min_amount >= 0),
    max_amount DECIMAL(10,2) CHECK (max_amount IS NULL OR max_amount > min_amount),
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(10,2) NOT NULL CHECK (discount_value >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(offer_id, tier_number),
    UNIQUE(offer_id, min_amount)
);

-- Step 4: Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_offer_cart_tiers_offer_id ON offer_cart_tiers(offer_id);
CREATE INDEX IF NOT EXISTS idx_offer_cart_tiers_amount_range ON offer_cart_tiers(min_amount, max_amount);

-- Step 5: Add RLS policies for offer_cart_tiers
ALTER TABLE offer_cart_tiers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_all_offer_cart_tiers" ON offer_cart_tiers
FOR ALL
TO public
USING (true)
WITH CHECK (true);

CREATE POLICY "offer_cart_tiers_select_policy" ON offer_cart_tiers
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

CREATE POLICY "offer_cart_tiers_insert_policy" ON offer_cart_tiers
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

CREATE POLICY "offer_cart_tiers_update_policy" ON offer_cart_tiers
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

CREATE POLICY "offer_cart_tiers_delete_policy" ON offer_cart_tiers
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM users
    WHERE users.id = auth.uid()
    AND users.role_type IN ('Admin', 'Master Admin')
  )
);

-- Step 6: Add trigger to update updated_at
CREATE OR REPLACE FUNCTION update_offer_cart_tiers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_offer_cart_tiers_updated_at ON offer_cart_tiers;
CREATE TRIGGER update_offer_cart_tiers_updated_at
    BEFORE UPDATE ON offer_cart_tiers
    FOR EACH ROW
    EXECUTE FUNCTION update_offer_cart_tiers_updated_at();

-- Step 7: Add helper function to get applicable tier for cart amount
CREATE OR REPLACE FUNCTION get_cart_tier_discount(
    p_offer_id INTEGER,
    p_cart_amount DECIMAL
)
RETURNS TABLE (
    tier_number INTEGER,
    discount_type VARCHAR(20),
    discount_value DECIMAL(10,2),
    min_amount DECIMAL(10,2),
    max_amount DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.tier_number,
        t.discount_type,
        t.discount_value,
        t.min_amount,
        t.max_amount
    FROM offer_cart_tiers t
    WHERE t.offer_id = p_offer_id
      AND p_cart_amount >= t.min_amount
      AND (t.max_amount IS NULL OR p_cart_amount <= t.max_amount)
    ORDER BY t.tier_number DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Step 8: Example data - Create a tiered cart discount offer
-- This is just an example, can be deleted after testing
DO $$
DECLARE
    v_offer_id INTEGER;
BEGIN
    -- Create a cart discount offer
    INSERT INTO offers (
        type, 
        name_ar, 
        name_en, 
        description_ar, 
        description_en,
        discount_type,
        discount_value,
        start_date, 
        end_date,
        is_active,
        branch_id, 
        service_type,
        show_on_product_page, 
        show_in_carousel, 
        send_push_notification
    ) VALUES (
        'cart',
        'خصم متدرج على إجمالي السلة',
        'Tiered Cart Discount',
        'احصل على خصم أكبر كلما زادت مشترياتك',
        'Get bigger discounts as your cart total increases',
        'percentage',
        0, -- Will be determined by tier
        NOW(),
        NOW() + INTERVAL '90 days',
        true,
        NULL,
        'both',
        false,
        true,
        true
    ) RETURNING id INTO v_offer_id;

    -- Insert 6 tiers
    INSERT INTO offer_cart_tiers (offer_id, tier_number, min_amount, max_amount, discount_type, discount_value) VALUES
    (v_offer_id, 1, 100.00, 199.99, 'percentage', 5.00),
    (v_offer_id, 2, 200.00, 299.99, 'percentage', 10.00),
    (v_offer_id, 3, 300.00, 399.99, 'percentage', 15.00),
    (v_offer_id, 4, 400.00, 499.99, 'percentage', 20.00),
    (v_offer_id, 5, 500.00, 599.99, 'percentage', 25.00),
    (v_offer_id, 6, 600.00, NULL, 'percentage', 30.00); -- NULL max_amount = unlimited
END $$;

-- Step 9: Verification
SELECT 
    o.id,
    o.name_en,
    o.type,
    t.tier_number,
    t.min_amount,
    t.max_amount,
    t.discount_type,
    t.discount_value
FROM offers o
LEFT JOIN offer_cart_tiers t ON o.id = t.offer_id
WHERE o.type = 'cart'
ORDER BY o.id, t.tier_number;

-- Test the function
SELECT * FROM get_cart_tier_discount(
    (SELECT id FROM offers WHERE type = 'cart' LIMIT 1),
    350.00 -- Test with 350 SAR cart
);

-- ============================================
-- Summary of Changes
-- ============================================
-- ✅ Removed priority field
-- ✅ Removed allow_stacking field
-- ✅ Created offer_cart_tiers table (up to 6 tiers)
-- ✅ Added RLS policies for security
-- ✅ Added helper function for tier lookup
-- ✅ Created example tiered cart offer
-- ============================================
