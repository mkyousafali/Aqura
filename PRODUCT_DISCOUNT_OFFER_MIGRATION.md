# Product Discount Offer Migration Plan

## Current Status

### Existing Offer Types
✅ **Bundle Offer** - Buy products together, get discount  
✅ **BOGO Offer** - Buy X Get Y (managed in `bogo_offer_rules` table)

### Missing Offer Type
❌ **Product Discount Offer** - Individual product percentage or special price discounts

---

## Migration Requirements

### 1. Database Schema Changes

**No schema changes required!** ✅

The `offers` table already supports product discount offers:
- `type` column accepts: `'product'`, `'bundle'`, `'bogo'`, `'cart'`
- `discount_type` column supports: `'percentage'`, `'fixed'`, `'special_price'`
- `discount_value` column stores the discount value

### 2. New Table: `offer_products`

**Purpose:** Store individual products with their specific offer pricing

```sql
CREATE TABLE IF NOT EXISTS offer_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id INTEGER REFERENCES offers(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id) ON DELETE CASCADE,
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

-- Indexes
CREATE INDEX idx_offer_products_offer_id ON offer_products(offer_id);
CREATE INDEX idx_offer_products_product_id ON offer_products(product_id);
CREATE INDEX idx_offer_products_active_lookup ON offer_products(offer_id, product_id) 
  WHERE offer_id IN (SELECT id FROM offers WHERE is_active = true);

-- Trigger for updated_at
CREATE TRIGGER update_offer_products_updated_at
  BEFORE UPDATE ON offer_products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- Comments
COMMENT ON TABLE offer_products IS 'Stores individual products included in product discount offers with their specific pricing';
COMMENT ON COLUMN offer_products.offer_qty IS 'Quantity of product required for this offer (e.g., 2 for "2 pieces for 39.95")';
COMMENT ON COLUMN offer_products.offer_percentage IS 'Percentage discount (used for percentage offer type only)';
COMMENT ON COLUMN offer_products.offer_price IS 'Special price for the offer quantity (used for special_price offer type only)';
COMMENT ON COLUMN offer_products.max_uses IS 'Maximum number of times this product offer can be used (NULL = unlimited)';
```

### 3. RLS Policies for `offer_products`

```sql
-- Enable RLS
ALTER TABLE offer_products ENABLE ROW LEVEL SECURITY;

-- Allow public to read active offer products
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

-- Allow authenticated users to manage offer products
CREATE POLICY "Authenticated users can manage offer products"
  ON offer_products
  FOR ALL
  TO authenticated
  USING (true)
  WITH CHECK (true);
```

---

## 4. Backend Functions

### A. Get Product Offers

```sql
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
  end_date TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.id,
    o.name_en,
    o.name_ar,
    o.type,
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
    o.end_date
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
```

### B. Validate Product Offer

```sql
CREATE OR REPLACE FUNCTION validate_product_offer(
  p_offer_id INTEGER,
  p_product_id UUID,
  p_quantity INTEGER
)
RETURNS BOOLEAN AS $$
DECLARE
  v_offer_qty INTEGER;
  v_max_uses INTEGER;
  v_current_uses INTEGER;
BEGIN
  -- Get offer details
  SELECT op.offer_qty, op.max_uses
  INTO v_offer_qty, v_max_uses
  FROM offer_products op
  WHERE op.offer_id = p_offer_id AND op.product_id = p_product_id;
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Check if quantity matches offer requirement
  IF p_quantity < v_offer_qty THEN
    RETURN FALSE;
  END IF;
  
  -- Check usage limits (implement usage tracking logic here)
  -- This would query a usage_logs table if implemented
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql STABLE;
```

---

## 5. Frontend Integration Status

### ✅ Completed Components

1. **ProductDiscountOfferWindow.svelte**
   - 2-step wizard (Offer Details → Product Selection)
   - Percentage Offer table with auto-calculated prices
   - Special Price Offer table with discount amounts
   - Stock validation (no enough stock warning)
   - Product filtering (hide already selected products)
   - Profit calculation (Offer Price - Cost × Qty)
   - Unit information display (name, qty, cost)
   - Responsive table with sticky headers
   - RTL/LTR bilingual support

2. **OfferManagement.svelte**
   - Product Discount button integration
   - Window opening for create/edit modes
   - Integration with window manager

### ⚠️ Pending Implementation

1. **Save Offer Functionality**
   - Create `offers` record with type='product'
   - Insert `offer_products` records for each selected product
   - Handle both percentage and special_price types
   - Validate data before submission

2. **Edit Mode Loading**
   - Query existing offer with products
   - Populate form fields from database
   - Load product list into appropriate offer type array

3. **Customer App Integration**
   - Display product offers on product cards
   - Show original price (strikethrough) and offer price
   - Offer badge/label display
   - Apply offer in cart calculation
   - Show savings in checkout

---

## 6. Migration Steps

### Step 1: Create `offer_products` Table ✅ READY
```bash
# Run the SQL migration
# File: create-offer-products-table.sql
```

### Step 2: Test Table Creation
```bash
node check-table-structure.js offer_products
```

### Step 3: Implement Save Functionality
- Update `ProductDiscountOfferWindow.svelte`
- Add `saveOffer()` function
- Insert into `offers` table
- Bulk insert into `offer_products` table

### Step 4: Implement Edit Mode
- Query offer by ID
- Load offer_products for that offer
- Populate percentageOffers or specialPriceOffers arrays

### Step 5: Customer App Updates
- Update product cards to show offers
- Update cart calculation logic
- Update checkout summary

### Step 6: Testing
- Create sample percentage offer (20% off)
- Create sample special price offer (2 for 39.95)
- Test product filtering
- Test stock validation
- Test save and edit modes
- Test customer app display

---

## 7. Sample Data for Testing

```sql
-- Sample Product Discount Offer (Percentage)
INSERT INTO offers (type, name_ar, name_en, description_ar, description_en, discount_type, discount_value, start_date, end_date, is_active, service_type)
VALUES (
  'product',
  'خصم 20% على الشوكولاتة',
  '20% OFF on Chocolate',
  'احصل على خصم 20% على كعك الشوكولاتة',
  'Get 20% discount on Chocolate Cake',
  'percentage',
  20,
  NOW(),
  NOW() + INTERVAL '30 days',
  true,
  'both'
) RETURNING id;

-- Insert offer products (assuming offer_id = 1)
INSERT INTO offer_products (offer_id, product_id, offer_qty, offer_percentage)
VALUES 
  (1, '64d1f75e-00e4-4d9c-af27-fef057501400', 1, 20.00), -- Chocolate Cake
  (1, '64d1f75e-00e4-4d9c-af27-fef057502400', 1, 20.00); -- Another chocolate product
```

---

## 8. Migration Checklist

- [ ] Create `offer_products` table
- [ ] Add RLS policies
- [ ] Create helper functions (`get_product_offers`, `validate_product_offer`)
- [ ] Implement `saveOffer()` in ProductDiscountOfferWindow
- [ ] Implement `loadOfferData()` for edit mode
- [ ] Test create functionality
- [ ] Test edit functionality
- [ ] Update customer app product cards
- [ ] Update cart calculation logic
- [ ] Update checkout display
- [ ] Add usage tracking (optional)
- [ ] Test end-to-end flow
- [ ] Deploy to production

---

## 9. Additional Considerations

### A. Offer Stacking
- Should product offers stack with other offers?
- Implement priority system if stacking allowed
- Document stacking rules

### B. Usage Tracking
- Track how many times each product offer is used
- Implement usage limits per customer
- Analytics for offer performance

### C. Performance
- Index on (offer_id, product_id) for fast lookups
- Cache active product offers
- Optimize queries for customer app

### D. Edge Cases
- Product deleted after offer created
- Offer expires while in cart
- Stock runs out during checkout
- Multiple offers on same product (priority handling)

---

## Status Summary

**Current State:** ✅ Frontend UI Complete  
**Next Step:** 🔄 Create `offer_products` table  
**After That:** 📝 Implement save/load functionality  
**Timeline:** Ready to migrate (awaiting approval)
