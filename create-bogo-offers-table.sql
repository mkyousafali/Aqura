-- Buy X Get Y (BOGO) Offers System Migration
-- Purpose: Add support for Buy X Get Y promotional offers
-- Date: 2025-11-12

-- Step 1: Create bogo_offer_rules table to store Buy X Get Y rules
CREATE TABLE IF NOT EXISTS bogo_offer_rules (
    id SERIAL PRIMARY KEY,
    offer_id INTEGER NOT NULL REFERENCES offers(id) ON DELETE CASCADE,
    
    -- Buy Product (X)
    buy_product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    buy_quantity INTEGER NOT NULL CHECK (buy_quantity > 0),
    
    -- Get Product (Y)
    get_product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    get_quantity INTEGER NOT NULL CHECK (get_quantity > 0),
    
    -- Discount Configuration
    discount_type VARCHAR(20) NOT NULL CHECK (discount_type IN ('free', 'percentage', 'amount')),
    discount_value DECIMAL(10, 2) DEFAULT 0 CHECK (discount_value >= 0),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure valid discount value based on type
    CONSTRAINT valid_discount_value CHECK (
        (discount_type = 'free') OR 
        (discount_type = 'percentage' AND discount_value > 0 AND discount_value <= 100) OR
        (discount_type = 'amount' AND discount_value > 0)
    )
);

-- Step 2: Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_bogo_offer_rules_offer_id ON bogo_offer_rules(offer_id);
CREATE INDEX IF NOT EXISTS idx_bogo_offer_rules_buy_product ON bogo_offer_rules(buy_product_id);
CREATE INDEX IF NOT EXISTS idx_bogo_offer_rules_get_product ON bogo_offer_rules(get_product_id);

-- Step 3: Add updated_at trigger
CREATE OR REPLACE FUNCTION update_bogo_offer_rules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_bogo_offer_rules_updated_at
    BEFORE UPDATE ON bogo_offer_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_bogo_offer_rules_updated_at();

-- Step 4: Add RLS policies
ALTER TABLE bogo_offer_rules ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read BOGO rules
CREATE POLICY "Allow read access to bogo_offer_rules"
    ON bogo_offer_rules
    FOR SELECT
    TO authenticated
    USING (true);

-- Allow service role full access
CREATE POLICY "Allow service role full access to bogo_offer_rules"
    ON bogo_offer_rules
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Step 5: Add comment for documentation
COMMENT ON TABLE bogo_offer_rules IS 'Stores Buy X Get Y (BOGO) offer rules - each rule defines a condition where buying X product(s) qualifies for discount on Y product(s)';
COMMENT ON COLUMN bogo_offer_rules.buy_product_id IS 'Product customer must buy (X)';
COMMENT ON COLUMN bogo_offer_rules.buy_quantity IS 'Quantity of buy product required';
COMMENT ON COLUMN bogo_offer_rules.get_product_id IS 'Product customer gets discount on (Y)';
COMMENT ON COLUMN bogo_offer_rules.get_quantity IS 'Quantity of get product that receives discount';
COMMENT ON COLUMN bogo_offer_rules.discount_type IS 'Type of discount: free (100% off), percentage (% off), or amount (fixed amount off)';
COMMENT ON COLUMN bogo_offer_rules.discount_value IS 'Discount value - 0 for free, 1-100 for percentage, or amount for fixed discount';

-- Step 6: Update offers table type enum to include 'bogo' if not already present
-- Note: Check current constraint first
DO $$
BEGIN
    -- Drop existing constraint if it exists
    ALTER TABLE offers DROP CONSTRAINT IF EXISTS offers_type_check;
    
    -- Add new constraint with 'bogo' type
    ALTER TABLE offers ADD CONSTRAINT offers_type_check 
        CHECK (type IN ('bundle', 'cart', 'product', 'bogo'));
END $$;

-- Verification queries (comment these out after running):
-- SELECT COUNT(*) as total_bogo_rules FROM bogo_offer_rules;
-- SELECT * FROM bogo_offer_rules LIMIT 5;
-- SELECT type, COUNT(*) FROM offers GROUP BY type;
