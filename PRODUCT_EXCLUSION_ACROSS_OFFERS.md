# Product Exclusion Across All Offer Types

## 🎯 Overview

This document describes the implementation of **universal product exclusion** across all offer types in the Aqura system. Once a product is included in any active offer, it will **not appear** as an available option when creating or editing other offers.

## ✅ Implementation Summary

### Problem
Previously, products could appear in multiple offer types simultaneously, creating potential conflicts:
- A product in a BOGO offer could also be added to a Bundle offer
- A product with a Percentage discount could also have a Special Price offer
- Inconsistent filtering logic across different offer windows

### Solution
Implemented comprehensive filtering in **all offer creation/editing windows** to exclude products that are already used in **any active offer type**:

1. **Percentage Offer Window** (`PercentageOfferWindow.svelte`)
2. **Special Price Offer Window** (`SpecialPriceOfferWindow.svelte`)
3. **Bundle Offer Window** (`BundleOfferWindow.svelte`)
4. **Buy X Get Y (BOGO) Offer Window** (`BuyXGetYOfferWindow.svelte`)

---

## 🔍 What Products Are Excluded?

When creating or editing any offer, the system now checks and excludes products from:

### 1. **offer_products Table**
- Products in **Percentage Discount** offers
- Products in **Special Price** offers
- Any other product-specific offers

### 2. **bogo_offer_rules Table**
- Products used as "Buy X" product in BOGO offers
- Products used as "Get Y" product in BOGO offers

### 3. **offer_bundles Table**
- Products included in any Bundle offer
- All products in the `required_products` array

---

## 📋 Changes Made

### 1. BuyXGetYOfferWindow.svelte
**Function Updated:** `loadUsedProductIds()`

**Added:**
```javascript
// 3. Load products from offer_products table (Percentage & Special Price offers)
let offerProductsQuery = supabaseAdmin
  .from('offer_products')
  .select(`
    product_id,
    offers!inner(id, is_active, end_date, type)
  `)
  .eq('offers.is_active', true)
  .gte('offers.end_date', new Date().toISOString());

// If editing, exclude products from the current offer
if (editMode && offerId) {
  offerProductsQuery = offerProductsQuery.neq('offers.id', offerId);
}

const { data: offerProducts, error: offerProductsError } = await offerProductsQuery;

offerProducts?.forEach((op: any) => {
  tempSet.add(op.product_id);
});
```

---

### 2. PercentageOfferWindow.svelte
**Function Updated:** `loadProductsInOtherOffers()`

**Added:**
```javascript
// Load products from BOGO offers
let bogoQuery = supabaseAdmin
  .from('bogo_offer_rules')
  .select(`
    buy_product_id,
    get_product_id,
    offers!inner(id, is_active, end_date)
  `)
  .eq('offers.is_active', true)
  .gte('offers.end_date', new Date().toISOString());

if (editMode && offerId) {
  bogoQuery = bogoQuery.neq('offers.id', offerId);
}

const { data: bogoData } = await bogoQuery;

bogoData?.forEach((rule: any) => {
  if (rule.buy_product_id) {
    productsInOtherOffers.add(rule.buy_product_id);
  }
  if (rule.get_product_id) {
    productsInOtherOffers.add(rule.get_product_id);
  }
});
```

---

### 3. SpecialPriceOfferWindow.svelte
**Function Updated:** `loadProductsInOtherOffers()`

**Added:** Same BOGO filtering logic as PercentageOfferWindow (see above)

---

### 4. BundleOfferWindow.svelte
**Function Updated:** `loadProducts()`

**Added:**
```javascript
// Get products from BOGO offers
let bogoQuery = supabaseAdmin
  .from('bogo_offer_rules')
  .select(`
    buy_product_id,
    get_product_id,
    offers!inner(id, is_active, end_date)
  `)
  .eq('offers.is_active', true)
  .gte('offers.end_date', new Date().toISOString());

if (editMode && offerId) {
  bogoQuery = bogoQuery.neq('offers.id', offerId);
}

const { data: bogoData } = await bogoQuery;

// Add products from BOGO offers
bogoData?.forEach((rule: any) => {
  if (rule.buy_product_id) {
    usedProductIds.add(rule.buy_product_id);
  }
  if (rule.get_product_id) {
    usedProductIds.add(rule.get_product_id);
  }
});
```

---

## 🔄 How It Works

### When Creating a New Offer

1. Admin opens any offer creation window (Percentage, Special Price, Bundle, or BOGO)
2. System loads all products from database
3. System queries ALL offer-related tables to find products in active offers:
   - `offer_products` (Percentage & Special Price offers)
   - `bogo_offer_rules` (BOGO offers)
   - `offer_bundles` (Bundle offers)
4. Products found in any active offer are **excluded** from the available products list
5. Admin can only select from products **not currently in any offer**

### When Editing an Existing Offer

1. Admin clicks "Edit" on an existing offer
2. System loads products but **excludes the current offer's products** from the filter
3. This allows admin to:
   - Keep existing products in the offer
   - Add new products (not in other offers)
   - Remove products from the offer
4. Products from **other active offers** remain excluded

---

## 🎨 User Experience

### Product Selection UI

**Before:**
```
Available Products (250 total)
- Product A (also in Bundle Offer #12) ❌ Conflict!
- Product B (also in BOGO Offer #8) ❌ Conflict!
- Product C ✅
```

**After:**
```
Available Products (200 total)
- Product C ✅
- Product D ✅
- Product E ✅

Products A & B are hidden (already in other offers)
```

---

## 🔧 Technical Details

### Active Offer Criteria
An offer is considered "active" if:
- `is_active = true`
- `end_date >= NOW()` (not expired)

### Edit Mode Handling
When editing an offer, the system:
- Queries: `.neq('offers.id', offerId)` or `.neq('offer_id', offerId)`
- This ensures products from **the current offer being edited** can still be managed
- Only products from **other offers** are excluded

### Database Queries
All filtering queries use **inner joins** with the `offers` table to ensure:
- Only active offers are checked
- Only offers with future end dates are considered
- Current offer (when editing) is properly excluded

---

## ✨ Benefits

1. **No Conflicts:** Products cannot be in multiple offers simultaneously
2. **Clear Admin UI:** Only valid products shown for selection
3. **Consistent Logic:** Same filtering rules across all offer types
4. **Edit Safety:** Editing an offer doesn't remove its own products from availability
5. **Data Integrity:** Prevents database inconsistencies

---

## 🧪 Testing Scenarios

### Test 1: Create New BOGO Offer
1. Create a BOGO offer with Product A and Product B
2. Open Percentage Offer window
3. ✅ Products A & B should NOT appear in available products

### Test 2: Create New Bundle
1. Create a Bundle with Products C, D, E
2. Open Special Price Offer window
3. ✅ Products C, D, E should NOT appear in available products

### Test 3: Edit Existing Offer
1. Edit a Percentage offer containing Product F
2. ✅ Product F should still appear as available/selected
3. ✅ Products from other offers should remain hidden

### Test 4: Cross-Category Exclusion
1. Create Percentage offer with Product G
2. Create BOGO offer (try to use Product G)
3. ✅ Product G should not appear in BOGO product selection
4. Create Bundle (try to use Product G)
5. ✅ Product G should not appear in Bundle product selection

---

## 📊 Database Tables Involved

| Table | Purpose | Columns Checked |
|-------|---------|----------------|
| `offer_products` | Percentage & Special Price offers | `product_id` |
| `bogo_offer_rules` | BOGO offers | `buy_product_id`, `get_product_id` |
| `offer_bundles` | Bundle offers | `required_products` (JSONB array) |
| `offers` | Parent offer metadata | `is_active`, `end_date` |

---

## 🚀 Future Enhancements

1. **Visual Indicators:** Show why a product is unavailable (e.g., "In Bundle Offer #12")
2. **Admin Override:** Allow Master Admin to force add products with conflict warnings
3. **Offer Priority:** Implement priority system to auto-resolve conflicts
4. **Expiry Handling:** Automatically make products available when offers expire

---

## 📝 Notes

- This implementation ensures **hard exclusion** - no product can be in multiple active offers
- The filtering happens at the **UI level** before product selection
- Database constraints remain as-is (no foreign key changes needed)
- All changes are **backward compatible** with existing offers

---

**Last Updated:** November 13, 2025
**Modified Files:**
- `BuyXGetYOfferWindow.svelte`
- `PercentageOfferWindow.svelte`
- `SpecialPriceOfferWindow.svelte`
- `BundleOfferWindow.svelte`
