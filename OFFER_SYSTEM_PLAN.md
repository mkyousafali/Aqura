# Offer System Implementation Plan

## Overview
Comprehensive offer system for Aqura customer app with desktop admin management interface.

---

## 1. Offer Types (6 Types)

### A. Product-Level Offers
1. **Percentage Discount** - Simple % off (e.g., 20% off)
2. **Fixed Amount Discount** - Fixed SAR discount (e.g., 5 SAR off)
3. **Buy X Get Y Free (BOGO)** - Buy 2 Get 1 Free, etc.

### B. Cart-Level Offers
4. **Minimum Purchase Offer** - Spend X, get Y off
5. **Bundle Offer** - Buy products together, get discount

### C. Customer-Specific Offers
6. **Personalized Offers** - Targeted by customer ID (loyalty, VIP, birthday)

---

## 2. Customer App Display Locations

### Product Page (`/customer/products`)
- Discount badge on product card (top-right)
- Strikethrough original price
- Offer labels: "BOGO", "Bundle", "Exclusive"
- Expiry countdown
- Personalized offer highlight

### Cart Page (`/customer/cart`)
- Applied offers section with green checkmarks
- Available offers section
- Total savings summary
- Progress bars for min purchase offers
- Bundle completion suggestions

### Checkout Page (`/customer/checkout`)
- Order summary with itemized offer discounts
- Total savings highlighted in green
- Expandable offer details
- Savings celebration message

### Bottom Cart Bar (Floating)
- Offer badge indicator
- "Saving X SAR" counter
- Animated notifications when offer applies
- Pulsing badge for time-sensitive offers

---

## 3. Admin Desktop Interface

### New Window: "Offer Management" 🎁

**Sidebar Location:** Under "Customer Management" or new "Marketing" section

### Main Dashboard
- **Stats Bar:** Active offers, total savings, most used, expiring soon
- **Card Grid:** All offers with color-coded badges by type
- **Filters:** Status, type, branch, date range
- **Search:** By name, type, status
- **Quick Actions per card:** Edit, Analytics, Pause, Delete, Duplicate

### Create/Edit Offer Form

**Step 1: Type Selection (Visual Cards)**
- Product Discount 📦
- Bundle Offer 🎁
- Customer-Specific 👤
- Cart-Level 🛒
- BOGO 🔄
- Min Purchase 💰

**Step 2: Offer Details**
- Names (AR/EN), descriptions
- Branch selection
- Priority level (1-10)
- Discount configuration (type-specific)
- Product/customer selection
- Validity period (start/end dates)
- Conditions: min quantity, usage limits, stacking rules
- Visibility settings: show on product page, carousel, push notification

**Step 3: Preview & Activate**
- Preview how offer appears to customers
- Mock calculation example
- Activate, Draft, or Schedule

### Offer Analytics Window
- Usage charts (daily/weekly)
- Total savings provided
- Orders using offer
- Conversion rates
- Customer insights (unique users, repeat usage)
- Product impact analysis
- Export CSV/PDF reports

### Quick Templates
1. Weekend Special (15% off)
2. New Customer Welcome (20 SAR off first order)
3. Bundle Deal (pre-configured bundles)
4. Flash Sale (30% off, 24hrs, first 50 customers)
5. Loyalty Reward (VIP discount)
6. Free Delivery Booster (spend threshold)

### Additional Features
- **Bulk Operations:** Pause/resume/delete multiple offers
- **Calendar View:** Monthly view with drag-and-drop scheduling
- **Customer Assignment Tool:** Bulk assign personalized offers with smart targeting
- **Conflict Resolution:** Warnings for overlapping offers with priority adjustment
- **Mobile Admin:** Quick activate/deactivate, emergency pause

---

## 4. Database Schema

### New Tables

**`offers`**
```sql
id, type (enum), name_ar, name_en, description_ar, description_en
discount_type, discount_value, start_date, end_date
is_active, priority, min_quantity, min_amount
branch_id (nullable), created_at, updated_at
```

**`offer_products`**
```sql
id, offer_id, product_id, unit_id (nullable)
```

**`offer_bundles`**
```sql
id, offer_id, bundle_name_ar, bundle_name_en
required_products (JSON), discount_amount
```

**`customer_offers`**
```sql
id, offer_id, customer_id, is_used, used_at
```

**`offer_usage_logs`**
```sql
id, offer_id, customer_id, order_id
discount_applied, used_at
```

---

## 5. Offer Priority & Stacking

**Application Order:**
1. Customer-Specific Offers (highest priority)
2. Product-Level Offers
3. Bundle Offers
4. BOGO Offers
5. Cart-Level Offers

**Stacking Rules:**
- Product-level: One per product (best wins)
- Cart-level: Can stack with product offers
- Customer-specific: Can stack with cart, replace product if better
- Bundles: Mutually exclusive with product-level on bundle items

---

## 6. Implementation Priority

1. **Phase 1:** Database schema + Percentage discount (enhance existing)
2. **Phase 2:** Admin dashboard + Create/edit form
3. **Phase 3:** Customer-specific offers + Assignment tool
4. **Phase 4:** Bundle offers + Cart page display
5. **Phase 5:** BOGO + Minimum purchase offers
6. **Phase 6:** Analytics dashboard + Templates
7. **Phase 7:** Fixed amount discount + Calendar view

---

## 7. User Experience Flow

### Customer Journey
1. Browse products → See offer badges
2. Add to cart → Offer auto-applies
3. View cart → See applied + available offers
4. Add more items → Progress toward threshold offers
5. Checkout → See full savings breakdown
6. Celebrate savings 🎉

### Admin Workflow
1. Open "Offer Management" window
2. View dashboard with stats
3. Click "Create New Offer"
4. Select type → Fill details → Select products/customers
5. Preview → Activate/Schedule
6. Monitor analytics
7. Adjust/pause as needed

---

## 8. Technical Integration Points

### Frontend Components to Create/Modify
- `OfferBadge.svelte` - Reusable badge component
- `OfferCard.svelte` - Product page offer display
- `AppliedOffers.svelte` - Cart applied offers section
- `AvailableOffers.svelte` - Cart available offers section
- `OfferSummary.svelte` - Checkout savings summary
- `OfferManagement.svelte` - Admin main dashboard
- `OfferForm.svelte` - Admin create/edit form
- `OfferAnalytics.svelte` - Admin analytics dashboard

### Backend API Endpoints
- `GET /api/offers/active` - Get active offers for customer
- `POST /api/offers/calculate` - Calculate offer discounts for cart
- `GET /api/admin/offers` - List all offers (admin)
- `POST /api/admin/offers` - Create new offer
- `PUT /api/admin/offers/:id` - Update offer
- `DELETE /api/admin/offers/:id` - Delete offer
- `GET /api/admin/offers/:id/analytics` - Get offer analytics
- `POST /api/admin/offers/bulk` - Bulk operations

### Database Functions Needed
- `calculate_product_offer_discount()` - Calculate product-level discounts
- `calculate_bundle_discount()` - Calculate bundle savings
- `calculate_cart_offer_discount()` - Calculate cart-level discounts
- `apply_best_offer()` - Apply best offer based on priority
- `check_offer_eligibility()` - Check if customer eligible for offer
- `log_offer_usage()` - Track offer usage

---

## 9. i18n Requirements

**Arabic/English Translation Needed:**
- Offer names, descriptions
- Badge labels: "خصم" / "Discount", "عرض حصري" / "Exclusive Offer"
- Savings messages: "وفّرت X ر.س" / "You saved X SAR"
- Progress messages: "أضف X أكثر" / "Add X more"
- Admin form labels, buttons, validation messages
- Analytics labels, chart titles

---

## 10. Success Metrics

**Business Goals:**
- Increase average order value by 20%
- Improve customer retention by 15%
- Boost conversion rate by 10%
- Track offer ROI (savings vs. revenue increase)

**Technical Metrics:**
- Offer calculation performance (< 100ms)
- Auto-apply accuracy (100%)
- Admin interface response time (< 500ms)
- Real-time analytics updates

---

## 11. Future Enhancements

- AI-powered offer recommendations
- A/B testing for offers
- Geolocation-based offers
- Time-of-day dynamic offers
- Gamification (scratch cards, spin wheel)
- Referral offer system
- Subscription-based recurring offers

---

**Total Estimated Development Time:** 4-6 weeks
**Priority Level:** High (Revenue Impact)
**Dependencies:** Existing cart system, product catalog, customer management

---

*Last Updated: November 11, 2025*
