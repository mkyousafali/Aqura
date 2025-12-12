# Migration Impact Analysis: Rename flyer_products → products

**Date:** December 12, 2025
**Objective:** Remove current `products` table and rename `flyer_products` to `products`

---

## 🔴 CRITICAL: Tables with Foreign Keys to `products`

These tables have `product_id` columns that reference `products.id`:

### 1. **`bogo_offer_rules`**
- `buy_product_id` (uuid, NOT NULL) → FK to `products.id`
- `get_product_id` (uuid, NOT NULL) → FK to `products.id`
- **Impact:** BOGO offers will break if IDs don't match
- **Action Required:** Remap product IDs from old products → new flyer_products

### 2. **`offer_products`**
- `product_id` (uuid, NOT NULL) → FK to `products.id`
- **Impact:** All product offers (percentage, special price) will break
- **Action Required:** Remap product IDs

### 3. **`offer_bundles`**
- `required_products` (jsonb) → Contains array of `{product_id, unit_id, quantity}`
- **Impact:** Bundle offers will break
- **Action Required:** Update JSONB data with new product IDs

### 4. **`order_items`**
- `product_id` (uuid, NOT NULL) → FK to `products.id`
- **Impact:** ALL HISTORICAL ORDERS will have broken product references
- **Action Required:** Either preserve old products table or remap historical order data

### 5. **`coupon_claims`** (if used)
- `product_id` (uuid, nullable)
- **Impact:** Coupon system references
- **Action Required:** Update references if any exist

---

## 📂 FILES THAT NEED CHANGES

### **Frontend Files (22 files):**

#### **Customer Interface (2 files)**
1. `frontend/src/routes/customer-interface/products/+page.svelte`
   - Line 91: `.from('products')` → `.from('flyer_products')` (or keep after rename)

2. `frontend/src/routes/customer-interface/checkout/+page.svelte`
   - Line 808: `.from('products')` → `.from('flyer_products')` (or keep after rename)

#### **API Endpoints (2 files)**
3. `frontend/src/routes/api/customer/products-with-offers/+server.ts`
   - Lines 56, 297, 459: `.from('products')` → `.from('flyer_products')`

4. `frontend/src/routes/api/customer/featured-offers/+server.ts`
   - Lines 123, 167, 173: `.from('products')` → `.from('flyer_products')`

#### **Admin Offers Components (6 files)**
5. `frontend/src/lib/components/desktop-interface/admin-customer-app/offers/BundleCreator.svelte`
6. `frontend/src/lib/components/desktop-interface/admin-customer-app/offers/BuyXGetYOfferWindow.svelte`
7. `frontend/src/lib/components/desktop-interface/admin-customer-app/offers/OfferForm.svelte`
8. `frontend/src/lib/components/desktop-interface/admin-customer-app/offers/PercentageOfferWindow.svelte`
9. `frontend/src/lib/components/desktop-interface/admin-customer-app/offers/SpecialPriceOfferWindow.svelte`
10. `frontend/src/lib/components/desktop-interface/admin-customer-app/offers/BundleOfferWindow.svelte`

#### **Admin Products Components (2 files)**
11. `frontend/src/lib/components/desktop-interface/admin-customer-app/products/ManageProductsWindow.svelte`
    - Lines 51, 100, 114: `.from('products')`

12. `frontend/src/lib/components/desktop-interface/admin-customer-app/products/ProductFormWindow.svelte`
    - Lines 75, 340, 368, 410: `.from('products')`

---

## 🗄️ DATABASE CHANGES REQUIRED

### **Step 1: Add Missing Columns to flyer_products**
✅ Already created: `20241212_add_columns_to_flyer_products.sql`

Adds:
- `product_serial`, `sale_price`, `cost`, `profit`, `profit_percentage`
- `current_stock`, `minim_qty`, `minimum_qty_alert`, `maximum_qty`
- `category_id`, `tax_category_id`, `tax_percentage`
- `unit_id`, `unit_qty`, `unit_name_en`, `unit_name_ar`
- `is_active`

### **Step 2: Data Migration Strategy**

#### **Option A: Preserve Historical Orders (RECOMMENDED)**
```sql
-- Keep old products table as products_archive
ALTER TABLE products RENAME TO products_archive;

-- Migrate/merge current product data into flyer_products
-- Map products.id → flyer_products.id (based on barcode matching)

-- Rename flyer_products to products
ALTER TABLE flyer_products RENAME TO products;
```

#### **Option B: Remap Everything (RISKY)**
```sql
-- Create ID mapping table
CREATE TABLE product_id_mapping (
  old_product_id UUID,
  new_product_id UUID,
  barcode TEXT
);

-- Populate mapping based on barcode
INSERT INTO product_id_mapping
SELECT p.id, fp.id, p.barcode
FROM products p
JOIN flyer_products fp ON p.barcode = fp.barcode;

-- Update all foreign keys
UPDATE offer_products SET product_id = (
  SELECT new_product_id FROM product_id_mapping 
  WHERE old_product_id = product_id
);

UPDATE bogo_offer_rules SET buy_product_id = (...);
UPDATE bogo_offer_rules SET get_product_id = (...);
-- etc for all tables

-- Drop old products table
DROP TABLE products;

-- Rename flyer_products
ALTER TABLE flyer_products RENAME TO products;
```

### **Step 3: Update Foreign Key Constraints**
After rename, foreign keys will automatically point to new `products` table.

### **Step 4: Recreate Indexes**
```sql
-- These indexes exist on old products table and need verification on new table
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_product_serial ON products(product_serial);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);
```

### **Step 5: Row Level Security (RLS)**
Check if `products` table has RLS policies and recreate them on renamed table.

---

## ⚠️ CRITICAL RISKS

### **Risk 1: Historical Order Data Loss**
- **Issue:** All past orders reference `products.id` via `order_items.product_id`
- **Impact:** Cannot view product details for historical orders
- **Mitigation:** Keep old products as `products_archive` for reference

### **Risk 2: Active Offers Breaking**
- **Issue:** All active offers have `product_id` references
- **Impact:** Customers cannot see offers, cart calculations fail
- **Mitigation:** Remap all offer product IDs before going live

### **Risk 3: Barcode Mismatches**
- **Issue:** If products exist in `products` but not in `flyer_products` (or vice versa)
- **Impact:** Data loss, orphaned offers
- **Mitigation:** Run validation query to ensure all products have matches

### **Risk 4: ID Conflicts**
- **Issue:** `flyer_products.id` might conflict with existing `products.id`
- **Impact:** Foreign key violations
- **Mitigation:** Use ID mapping table

---

## ✅ VALIDATION QUERIES

### **Query 1: Check Product Overlap**
```sql
-- Products in products table but NOT in flyer_products
SELECT p.id, p.product_serial, p.barcode, p.product_name_en
FROM products p
LEFT JOIN flyer_products fp ON p.barcode = fp.barcode
WHERE fp.id IS NULL;

-- Products in flyer_products but NOT in products
SELECT fp.id, fp.barcode, fp.product_name_en
FROM flyer_products fp
LEFT JOIN products p ON fp.barcode = p.barcode
WHERE p.id IS NULL;
```

### **Query 2: Count Offer Dependencies**
```sql
-- Count offers using products
SELECT COUNT(*) as offer_products_count FROM offer_products;
SELECT COUNT(*) as bogo_rules_count FROM bogo_offer_rules;
SELECT COUNT(*) as bundles_count FROM offer_bundles;

-- Count historical orders
SELECT COUNT(*) as order_items_count FROM order_items;
```

### **Query 3: Check for Orphaned References**
```sql
-- Offer products with no matching product
SELECT op.id, op.product_id
FROM offer_products op
LEFT JOIN products p ON op.product_id = p.id
WHERE p.id IS NULL;
```

---

## 📋 MIGRATION CHECKLIST

### **Phase 1: Preparation (DO FIRST)**
- [ ] **Backup entire database**
- [ ] Run validation queries above
- [ ] Count total products in both tables
- [ ] Identify products that exist in only one table
- [ ] Test in development environment first

### **Phase 2: Schema Migration**
- [ ] Run `20241212_add_columns_to_flyer_products.sql`
- [ ] Verify all columns added successfully
- [ ] Populate new columns with data from `products` table

### **Phase 3: Data Migration**
- [ ] Create ID mapping table (barcode-based)
- [ ] Update `offer_products.product_id` references
- [ ] Update `bogo_offer_rules.buy_product_id` and `get_product_id`
- [ ] Update `offer_bundles.required_products` JSONB
- [ ] Decide on `order_items` strategy (archive vs remap)

### **Phase 4: Table Rename**
- [ ] Rename `products` → `products_archive` (or drop if remapping all)
- [ ] Rename `flyer_products` → `products`
- [ ] Verify foreign keys still work

### **Phase 5: Code Updates**
- [ ] Update 2 API endpoint files
- [ ] Update 2 customer interface files
- [ ] Update 8 admin component files
- [ ] Test all functionality

### **Phase 6: Testing**
- [ ] Test customer app product listing
- [ ] Test all offer types (percentage, special price, BOGO, bundle)
- [ ] Test checkout and order creation
- [ ] Test admin product management
- [ ] Verify historical orders still viewable

### **Phase 7: Rollback Plan**
- [ ] Keep database backup for 7 days
- [ ] Document rollback SQL scripts
- [ ] Have old code version in git

---

## 🎯 RECOMMENDED APPROACH

### **SAFE Migration Path:**

1. **Add columns to flyer_products** ✅ (Already done)
2. **Sync data from products → flyer_products** (one-time copy)
3. **Keep old products as products_archive** (preserve history)
4. **Rename flyer_products → products_new** (test first)
5. **Test everything with products_new**
6. **When confident: Swap tables** (products → products_old, products_new → products)
7. **Update code to use new table**
8. **Monitor for 48 hours**
9. **Archive products_old after verification**

---

## 📊 ESTIMATED EFFORT

- **Database Migration:** 4-6 hours
- **Code Updates:** 2-3 hours
- **Testing:** 4-6 hours
- **Monitoring:** 48 hours
- **Total:** 2-3 days

---

## ❓ QUESTIONS TO ANSWER BEFORE PROCEEDING

1. **How many products exist in each table currently?**
2. **How many active offers depend on products?**
3. **How many historical orders exist?**
4. **Do we need to preserve historical order data?**
5. **Are product barcodes unique and reliable for matching?**
6. **Is there a maintenance window for this migration?**
7. **Can we afford temporary downtime?**

---

## 🚀 READY TO PROCEED?

Please confirm:
1. ✅ You've backed up the database
2. ✅ You've run validation queries
3. ✅ You understand the risks
4. ✅ You have rollback plan ready

**Then we can create the complete migration scripts.**
