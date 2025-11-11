# Multiple Offers on Same Product - How It Works

## Overview

The Aqura offer system is designed to support **multiple simultaneous offers on the same product**. This document explains how the system handles multiple offers, prioritization, stacking, and customer experience.

---

## 📊 Database Architecture

### Product-Offer Relationships

**One Product → Many Offers** (Many-to-Many Relationship)

```
products table (UUID)
    ↓
offer_products table (junction table)
    ↓
offers table (INTEGER)
```

**Example**: Fresh Apples (product_id: `64d1ee39-234b-4e56-bc97-ec5340e729f2`) can be in:
- Offer #1: "Weekend Special - 20% off Fresh Fruits"
- Offer #5: "Flash Sale - 30% off Apples"
- Offer #6: "Healthy Breakfast Bundle" (with milk)

All three offers are **independent** and can run simultaneously.

---

## 🎯 How Admin Manages Multiple Offers

### Creating Offers with Overlapping Products

1. **Admin creates Offer A** with Product X
   - Selects Product X in product selector
   - Saves offer
   - `offer_products` table gets entry: `(offer_id: A, product_id: X)`

2. **Admin creates Offer B** with Product X (again)
   - Opens new offer form
   - Selects same Product X
   - Saves offer
   - `offer_products` table gets another entry: `(offer_id: B, product_id: X)`

**Result**: Product X now has 2 active offers

### Editing Offers - Product Selection UI

When admin clicks "Edit" on an existing offer:

1. **Button Shows Current Count**
   ```
   + Select Products (3)
   ```
   - Shows number of products already in the offer
   - Loaded from `offer_products` table via `loadOfferProducts()`

2. **Product Selector Window Opens**
   - **Top Section**: Selected products appear first with:
     - ✓ Green "Selected" badge
     - Red ✕ remove button
     - Blue highlighted row
   - **Bottom Section**: Remaining unselected products

3. **Admin Can**:
   - ✅ Add more products (click unselected rows)
   - ✅ Remove products (click ✕ button on selected products)
   - ✅ Search/filter products
   - ✅ Select all / Clear all
   - ✅ See live count updates

4. **On Save**:
   - Deletes old `offer_products` entries for this offer
   - Inserts new entries for updated selection
   - Other offers using same products are **not affected**

---

## 🛍️ Customer Experience - Multiple Offers Display

### Product Page View

When customer views a product with multiple offers:

```
[Product Image: Fresh Apples]
Price: 10 SAR

Active Offers:
🏷️ Weekend Special - 20% off     → Final: 8 SAR
🏷️ Flash Sale - 30% off           → Final: 7 SAR ⭐ Best Deal
🏷️ Free Delivery (100+ SAR)       → Apply at checkout
```

**Display Logic**:
1. Query all active offers containing this product
2. Calculate final price for each offer
3. Highlight best discount
4. Show cart-level offers separately

### Cart View - Offer Application

**Scenario**: Customer adds 2kg Fresh Apples + 2L Milk

**Available Offers**:
1. Product Offer: 20% off Apples
2. Bundle Offer: Buy Apples + Milk, save 10 SAR
3. Cart Offer: Free delivery (100+ SAR)

**Calculation Logic**:

```javascript
// Option 1: Product offer only
Apples (20% off): 10 SAR → 8 SAR
Milk: 15 SAR
Total: 23 SAR
Delivery: 15 SAR
Final: 38 SAR

// Option 2: Bundle offer
Apples + Milk Bundle: -10 SAR discount
Total: 15 SAR
Delivery: 15 SAR
Final: 30 SAR ⭐ Best without stacking

// Option 3: If stacking allowed
Bundle (-10 SAR) + Free Delivery (-15 SAR)
Total: 15 SAR
Final: 15 SAR ⭐ Best with stacking
```

**System Automatically**:
- Calculates all valid offer combinations
- Respects `allow_stacking` flag per offer
- Applies best discount (or stack if allowed)
- Shows breakdown in cart

---

## 🔢 Offer Prioritization & Stacking

### Priority System

Each offer has a `priority` field (1-10):
- **10**: Highest priority (Flash Sales, Limited Time)
- **5**: Normal priority (Regular promotions)
- **1**: Lowest priority (Generic discounts)

**When multiple offers apply**:
1. System checks `allow_stacking` flag
2. If stacking **NOT** allowed: Apply highest priority offer only
3. If stacking **allowed**: Combine compatible offers

### Stacking Rules

**Compatible Stacking** (can combine):
- ✅ Product offer + Cart offer (e.g., 20% off + Free Delivery)
- ✅ Bundle offer + Cart offer
- ✅ Customer offer + Min purchase offer

**Incompatible Stacking** (exclusive):
- ❌ Multiple product offers on same item (pick best)
- ❌ Multiple bundle offers including same products
- ❌ Multiple BOGO offers on same item

**Example**:
```sql
-- Offer A: 20% off Apples, allow_stacking = true
-- Offer B: Free Delivery 100+ SAR, allow_stacking = true
-- Result: BOTH apply (compatible types)

-- Offer A: 20% off Apples, allow_stacking = false
-- Offer C: 30% off Apples, allow_stacking = false
-- Result: Only Offer C applies (higher discount, higher priority)
```

---

## 📈 Usage Tracking with Multiple Offers

### Tracking Individual Offer Performance

Each offer tracks usage independently via `offer_usage_logs`:

```sql
-- Customer uses Apples in Order #123
INSERT INTO offer_usage_logs (offer_id, customer_id, order_id, used_at, discount_amount)
VALUES 
  (1, 'customer-uuid', 123, NOW(), 2.00),  -- Weekend Special gave 2 SAR off
  (3, 'customer-uuid', 123, NOW(), 15.00); -- Free Delivery gave 15 SAR off
```

**Admin Dashboard Shows**:
```
Offer #1: Weekend Special
- Times Used: 45
- Total Savings: 180 SAR
- Products: Fresh Apples (20 uses), Tomatoes (25 uses)

Offer #5: Flash Sale
- Times Used: 12
- Total Savings: 96 SAR  
- Products: Fresh Apples (12 uses)
```

**Product Analytics**:
```
Product: Fresh Apples
- Total Offers: 3 active
- Most Used Offer: Flash Sale (30% off)
- Total Discount Given: 276 SAR
- Usage Count: 57 orders
```

---

## 🔄 Lifecycle Example - Multiple Offers on Apples

### Week 1: Single Offer
```
Offer: "Weekend Special - 20% off Fresh Fruits"
Products: Apples, Tomatoes, Carrots
Status: Active
Usage: Apples used 25 times
```

### Week 2: Add Flash Sale
```
Offer #1: "Weekend Special - 20% off" (still active)
Products: Apples, Tomatoes, Carrots
Usage: Apples used 10 times (some customers prefer this)

Offer #5: "Flash Sale - 30% off Apples" (NEW)
Products: Apples only
Priority: 10 (higher)
Usage: Apples used 40 times (better discount)
```

**Customer sees**: Both offers, system auto-applies best (30% off)

### Week 3: Add Bundle
```
Offer #1: Still active (20% off)
Offer #5: Still active (30% off)

Offer #6: "Breakfast Bundle" (NEW)
Products: Apples + Milk
Discount: 10 SAR fixed
Usage: 15 bundle purchases
```

**Customer buying Apples only**: Gets 30% off (Offer #5)
**Customer buying Apples + Milk**: Gets Bundle (Offer #6) if total savings > 30% off apples

### Week 4: Flash Sale Ends
```
Offer #1: Still active (20% off)
Offer #5: Expired (30% off ended)
Offer #6: Still active (Bundle)
```

**Apples now only in Offer #1** (back to 20% off individual purchases)

---

## 🛡️ Conflict Resolution

### Same Product, Different Discount Types

**Scenario**: Apples in 2 offers
- Offer A: 20% off (percentage)
- Offer B: 5 SAR fixed discount

**Resolution**:
1. Calculate final price for each
   - Original: 10 SAR
   - Offer A: 10 - (10 × 0.20) = 8 SAR
   - Offer B: 10 - 5 = 5 SAR
2. Apply best discount (Offer B: 5 SAR)
3. Log in `offer_usage_logs` with `offer_id = B`

### Usage Limits with Multiple Offers

**Scenario**: Customer has used Offer A (max 5 per customer)
- Offer A: 30% off Apples (used 5/5 times) ❌ Exhausted
- Offer B: 20% off Apples (used 0/3 times) ✅ Available

**Resolution**:
- System checks `max_uses_per_customer` for each offer
- Automatically falls back to Offer B
- Customer still gets discount (just lower)

### Branch/Service Type Conflicts

**Scenario**: Customer ordering delivery from Branch 1
- Offer A: 25% off, Branch 1, Pickup only ❌
- Offer B: 15% off, All branches, Delivery only ✅

**Resolution**:
- Filter offers by `branch_id` and `service_type`
- Only show applicable offers
- Customer sees Offer B only

---

## 📋 Summary - Key Points

| Aspect | How It Works |
|--------|--------------|
| **Product-Offer Relation** | Many-to-Many via `offer_products` table |
| **Multiple Active Offers** | ✅ Same product can be in unlimited offers |
| **Editing Offers** | Admin sees selected products at top, can add/remove |
| **Customer Display** | Shows all applicable offers, highlights best |
| **Discount Application** | Auto-applies best discount or stacks (if allowed) |
| **Usage Tracking** | Independent per offer via `offer_usage_logs` |
| **Priority System** | 1-10 scale, higher priority wins if no stacking |
| **Stacking** | Controlled by `allow_stacking` flag |
| **Conflict Resolution** | Best discount wins, respects limits and filters |

---

## 🚀 Future Enhancements

### Planned Features
- [ ] **Offer Conflict Alerts**: Warn admin when creating overlapping offers
- [ ] **Performance Analytics**: Show which offer performs best per product
- [ ] **A/B Testing**: Test different discount strategies on same products
- [ ] **Smart Recommendations**: Suggest optimal offer combinations
- [ ] **Bulk Product Management**: Add/remove products across multiple offers
- [ ] **Offer Templates**: Quick-create offers based on successful patterns

### Customer-Facing Features
- [ ] **Offer Comparison**: Side-by-side view of all offers on product
- [ ] **Savings Calculator**: Show total savings with different offer combinations
- [ ] **Offer Notifications**: Alert customers when better offer becomes available
- [ ] **Personalized Offers**: Show customer-specific offers prominently

---

## 📞 Support

For questions about multiple offers:
- Check admin dashboard analytics for offer performance
- Review `offer_products` table for product associations
- Query `offer_usage_logs` for actual customer usage
- Contact development team for complex stacking scenarios
