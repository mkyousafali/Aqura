 🎯 Complete Offer System Implementation Plan - Customer Mobile App

 Executive Summary

Transform the Aqura customer mobile app into a comprehensive offer-enabled shopping experience. Customers will see, understand, and benefit from 5 types of offers across all shopping touchpoints.

---

 📱 1. CUSTOMER JOURNEY WITH OFFERS

 Step 1: Customer Opens App ✅ COMPLETED
- ✅ Home Page LED display implemented - displays featured active offers, each product card shown separately for 2 seconds
- ✅ Featured offers API endpoint created and integrated
- ✅ Personalized offers badge system ready for customer-specific exclusive deals

 Step 2: Customer Browses Products ✅ SPECIAL PRICE OFFERS COMPLETED
- ✅ Product Cards show special price offer badges (orange colored)
- ✅ Visual indicators: colored badges with icons using OfferBadge component
- ✅ Original price with strikethrough + Offer price prominently displayed in green
- ✅ "Save X SAR" message below price with green background
- ✅ Filter products by "On Offer" toggle button
- ✅ Sort by "Best Deals" (highest discount first)
- ⏳ TODO: Add percentage, BOGO, and bundle offer badges (next phase)
- ⏳ TODO: Add expiring soon countdown timer display

 Step 3: Customer Views Product Details
- Expanded offer information popup when tapping offer badge
- Clear explanation of offer terms
- Countdown timer if offer expires soon
- "Limited uses remaining" urgency messaging
- Related offer suggestions (e.g., "Buy this + X to unlock BOGO")

 Step 4: Customer Adds to Cart
- Real-time offer validation (check limits, expiry, availability)
- Success animation when offer applied
- Immediate savings calculation displayed
- BOGO opportunity detection: "Add Product Y to get it free!"
- Bundle suggestion: "Complete the bundle and save more"

 Step 5: Customer Reviews Cart
- Each item shows if offer is applied with green checkmark
- Offer name displayed under product name
- Original price vs offer price comparison per item
- Running total of offer savings prominently shown
- Cart-level discount progress bar (for tiered cart offers)
- Motivational messages: "Add 50 SAR more to unlock 15% discount!"
- BOGO suggestions if customer has bought X but not Y yet

 Step 6: Customer Proceeds to Checkout
- Complete offer summary card at top
- List of all applied offers with individual savings
- Total savings highlighted in large, green font with celebration icon
- Final price breakdown:
  - Subtotal (before offers)
  - Product offer discounts (-X SAR)
  - Cart-level discounts (-Y SAR)
  - Delivery fee
  - FINAL TOTAL (with "You saved Z SAR!" message)
- Final validation before order placement
- Warning if any offer expired during checkout session

 Step 7: Order Confirmation
- Success screen shows total savings achieved
- Offer usage recorded in database
- Customer usage counters updated
- Total offer usage counters incremented
- Celebratory animation if significant savings

 Step 8: Post-Purchase
- Order history shows offers used
- Savings history tracking
- Personalized recommendations for future offers
- Email/SMS notification for new offers

---

 🎁 2. OFFER TYPES & HOW THEY WORK

 A. Percentage Offers (📊)
What It Is:
- X% discount on specific products
- Example: 15% off on Water Bottles

How Customer Sees It:
- Product Page: Blue badge "15% OFF"
- Cart: Original 10 SAR → Now 8.50 SAR (Save 1.50 SAR)
- Checkout: Listed as "Summer Sale - Water Bottle: -1.50 SAR"

Usage Limits:
- Each product has individual `max_uses` (e.g., first 20 customers)
- Offer-level `max_uses_per_customer` (e.g., each customer can buy 3 times)

---

 B. Special Price Offers (💰)
What It Is:
- Fixed special price on products
- Example: Orange Juice normally 15 SAR, now 10 SAR

How Customer Sees It:
- Product Page: Orange badge "Special 10 SAR"
- Cart: Was 15 SAR → Special Price 10 SAR (Save 5 SAR)
- Checkout: Listed as "Weekend Special - Orange Juice: -5 SAR"

Usage Limits:
- Same as percentage offers
- Product-specific and offer-level limits

---

 C. Buy X Get Y Offers (BOGO) (🎁)
What It Is:
- Buy certain quantity of Product X, get Product Y free/discounted
- Example: Buy 2 Croissants, Get 1 Coffee Free

How Customer Sees It:
- Product Page: Pink badge "Buy 2 Get 1 Free"
- Cart (if customer bought X but not Y): 
  - Suggestion card: "🎁 You bought 2 Croissants! Add 1 Coffee to get it FREE"
  - "Add Now" button pre-fills coffee to cart
- Cart (if customer added both):
  - Croissant: 2 × 5 SAR = 10 SAR
  - Coffee: 1 × 8 SAR = ~~8 SAR~~ FREE (Save 8 SAR) ✓
- Checkout: "BOGO Deal: -8 SAR"

Usage Limits:
- Offer-level limits apply
- Tracks that customer used this specific BOGO rule

---

 D. Bundle Offers (📦)
What It Is:
- Package of multiple products sold together at discount
- Example: Breakfast Bundle (2 Croissants + Coffee + Juice) = 25 SAR instead of 35 SAR

How Customer Sees It:
- Product Page: Purple badge "Bundle Deal"
- Offer Details Modal: Shows all bundle contents with individual discounts
- Cart: 
  - Bundle listed as single item with breakdown:
    - 2× Croissant (15% off each)
    - 1× Coffee (20% off)
    - 1× Juice (10% off)
    - Bundle Total: 25 SAR (Save 10 SAR)
- Checkout: "Breakfast Bundle: -10 SAR"

Usage Limits:
- Offer-level limits
- Customer can buy multiple bundles if allowed

---

 E. Cart Discount Offers (🛒)
What It Is:
- Tiered discounts based on cart total
- Example:
  - Spend 200 SAR → 5% off
  - Spend 400 SAR → 10% off  
  - Spend 600 SAR → 15% off

How Customer Sees It:
- Bottom Cart Bar: Progress indicator
  - "Add 85 SAR more to unlock 10% discount!"
  - Green progress bar showing how close to next tier
- Cart Page: Active tier highlighted
  - Current: "Spend 400+ SAR → 10% OFF ✓"
  - Next: "Spend 600+ SAR → 15% OFF (Add 175 SAR more)"
- Cart Summary:
  - Subtotal: 450 SAR
  - Cart Discount (10%): -45 SAR
  - Delivery: 15 SAR
  - Total: 420 SAR
- Fireworks Animation: When customer unlocks new tier

Usage Limits:
- Offer-level limits
- Can be combined with product offers (stacking)

---

 🎨 3. VISUAL DESIGN SYSTEM

 Color Coding:
- Percentage: Blue gradient (`3b82f6` → `2563eb`)
- Special Price: Orange gradient (`f97316` → `ea580c`)
- BOGO: Pink gradient (`ec4899` → `db2777`)
- Bundle: Purple gradient (`a855f7` → `9333ea`)
- Cart Discount: Green gradient (`10b981` → `059669`)

 Badge Styles:
```
┌─────────────────┐
│ 📊 15% OFF      │  ← Small badge on product card
└─────────────────┘

┌─────────────────────────────┐
│ 🎁 Buy 2 Get 1 Free        │  ← Medium badge in cart
│ Save up to 8 SAR!          │
└─────────────────────────────┘

┌────────────────────────────────────┐
│ 🛒 Cart Discount Active!          │  ← Large banner
│ You're saving 45 SAR (10% OFF)    │
│ Add 175 SAR to unlock 15% OFF →   │
└────────────────────────────────────┘
```

 Typography:
- Offer Name: Bold, 16px, Brand color
- Original Price: Gray, 14px, Strikethrough
- Offer Price: Bold, 18px, Green
- Savings Amount: Bold, 14px, Green with icon

 Animations:
- Pulse: Badge pulses when offer first appears
- Confetti: When cart discount tier unlocked
- Slide-in: BOGO suggestion slides from bottom
- Checkmark: Green checkmark animates when offer applied
- Countdown: Timer ticks down if offer expires soon

---

 🔧 4. TECHNICAL ARCHITECTURE

 Backend API Endpoints:

1. Get Products with Offers
- Endpoint: `GET /api/customer/products-with-offers`
- Input: branchId, serviceType (delivery/pickup)
- Output: Products array with offer data enriched
- Logic: Join products with active offers, calculate offer prices

2. Get Active Offers List
- Endpoint: `GET /api/customer/offers`
- Input: branchId, serviceType, customerId (for personalized)
- Output: All active offers with details
- Logic: Filter by active status, valid dates, branch, service type

3. Validate Offer Usage
- Endpoint: `POST /api/customer/offers/validate`
- Input: offerId, customerId, productId (optional)
- Output: Valid true/false, remaining uses, reason if invalid
- Logic: Check total limits, per-customer limits, product limits, expiry

4. Calculate Cart with Offers
- Endpoint: `POST /api/customer/cart/calculate`
- Input: Cart items array, branchId, serviceType, customerId
- Output: Complete breakdown with all discounts applied
- Logic:
  1. Calculate product-level offers
  2. Detect BOGO opportunities
  3. Apply bundle discounts
  4. Calculate cart-level discount
  5. Return detailed breakdown

5. Record Offer Usage
- Endpoint: `POST /api/customer/offers/record-usage`
- Input: Order data with offers used
- Output: Success confirmation
- Logic: Insert into offer_usage_logs, increment counters

6. Get Offer Details
- Endpoint: `GET /api/customer/offers/{offerId}`
- Input: offerId
- Output: Complete offer details (products, rules, tiers, terms)
- Logic: Fetch offer with all related data (products, bundles, BOGO rules, tiers)

---

 Database Schema:

Existing Tables:
- `offers` - Main offer metadata
- `offer_products` - Products in percentage/special price offers
- `offer_cart_tiers` - Cart discount tiers
- `bogo_offer_rules` - Buy X Get Y rules
- `offer_bundles` - Bundle definitions
- `bundle_items` - Items within bundles
- `offer_usage_logs` - Usage tracking
- `customers` - Customer accounts

Key Fields:
- `offers.current_total_uses` - Running counter of total uses
- `offers.max_total_uses` - Maximum total uses allowed
- `offers.max_uses_per_customer` - Maximum per customer
- `offer_products.max_uses` - Per-product usage limit
- `offer_usage_logs.customer_id` - Track who used it
- `offer_usage_logs.discount_applied` - Track savings

---

 Frontend Components to Create:

1. OfferBadge.svelte
- Reusable badge component
- Props: offerType, discountValue, size (small/medium/large)
- Color-coded by offer type
- Icon + text display

2. OfferDetailModal.svelte
- Full-screen modal showing offer details
- Sections: Image, Description, Terms, Products/Rules, Validity
- "Shop Now" button
- Swipe to close

3. BogoSuggestion.svelte
- Suggestion card for BOGO opportunities
- "You bought X, add Y to get discount" message
- Quick add button
- Dismissable

4. CartOfferProgress.svelte
- Progress bar for cart-level offers
- Shows current tier and next tier
- Amount remaining to unlock next tier
- Visual progress indicator

5. FeaturedOffers.svelte
- Carousel/slider for home page
- Auto-rotating offer cards
- Swipe navigation
- Tap to view details

6. OfferSummaryCard.svelte
- Checkout summary of all applied offers
- List format with individual savings
- Total savings highlighted
- Collapsible detail view

7. PriceDisplay.svelte
- Reusable price component
- Shows original price (strikethrough) + offer price
- Savings amount with icon
- Bilingual support (Arabic/English)

---

 Frontend Stores:

1. offers.js
- Store active offers data
- Cache offers to reduce API calls
- Reactive updates when offers change
- Functions: loadOffers(), getOfferById(), filterOffers()

2. offerCalculations.js
- Pure calculation functions
- calculateProductOffer()
- detectBogoOpportunities()
- calculateCartDiscount()
- applyOfferToCart()

3. cart.js (extend existing)
- Add offer tracking to cart items
- Calculate total savings
- Detect applicable offers
- Handle offer validation

---

 🧮 5. CALCULATION LOGIC

 Product Offer Calculation:
```
Original Price: 10 SAR
Quantity: 2
Offer: 15% off

Calculation:
- Total before discount = 10 × 2 = 20 SAR
- Discount amount = 20 × 0.15 = 3 SAR
- Final price = 20 - 3 = 17 SAR
- Savings = 3 SAR
```

 BOGO Calculation:
```
Buy 2 Croissants @ 5 SAR each = 10 SAR
Get 1 Coffee @ 8 SAR = FREE

Calculation:
- Croissants: 2 × 5 = 10 SAR
- Coffee: 1 × 8 = 8 SAR
- BOGO discount: -8 SAR (100% off coffee)
- Final: 10 SAR
- Savings: 8 SAR
```

 Cart Discount Calculation:
```
Cart Subtotal: 450 SAR
Tier: Spend 400+ → 10% OFF

Calculation:
- Eligible amount: 450 SAR
- Discount: 450 × 0.10 = 45 SAR
- After discount: 450 - 45 = 405 SAR
- Plus delivery: +15 SAR
- Final total: 420 SAR
- Savings: 45 SAR
```

 Stacking Rules:
```
Product offers + Cart offers = ✅ CAN STACK
- Product offer applies first
- Then cart discount on new subtotal

Example:
1. Product A: 100 SAR → 15% off = 85 SAR
2. Product B: 200 SAR → 10% off = 180 SAR
3. Subtotal after product offers: 265 SAR
4. Cart discount (5% on 265): -13.25 SAR
5. Final: 251.75 SAR
6. Total savings: 48.25 SAR

Multiple product offers on same item = ❌ CANNOT STACK
- Highest discount wins
```

---

 🔒 6. USAGE CONTROL & LIMITS

 Three-Level Limit System:

Level 1: Offer-Wide Total Limit
- Field: `max_total_uses`
- Applies to: All customers combined
- Example: "First 100 customers only"
- Behavior: Offer expires after 100th use

Level 2: Per-Customer Limit
- Field: `max_uses_per_customer`
- Applies to: Each individual customer
- Example: "Each customer can use 3 times"
- Behavior: Customer locked out after 3 uses

Level 3: Product-Specific Limit
- Field: `offer_products.max_uses`
- Applies to: Specific product in offer
- Example: "Water bottle offer limited to 50 uses"
- Behavior: That product's offer expires after 50 uses

 Validation Flow:
```
Customer adds product with offer to cart
    ↓
Check: Is offer active? (is_active = true)
    ↓
Check: Is offer within date range? (start_date ≤ now ≤ end_date)
    ↓
Check: Has total limit been reached? (current_total_uses < max_total_uses)
    ↓
Check: Has customer reached their limit? (customer_usage_count < max_uses_per_customer)
    ↓
Check: Has product-specific limit been reached? (product_usage_count < max_uses)
    ↓
If all pass: ✅ Apply offer
If any fail: ❌ Show appropriate error message
```

 Usage Recording:
```
When order is placed:
1. For each item with offer:
   - Insert row into offer_usage_logs table
   - Record: offer_id, customer_id, product_id, discount_applied, timestamp
   
2. Update offer counters:
   - Increment offers.current_total_uses
   
3. Check if limits reached:
   - If current_total_uses >= max_total_uses: Mark offer as exhausted
   - If customer_usage >= max_uses_per_customer: Block customer from reusing
```

---

 📊 7. USER INTERFACE PAGES

 Page 1: Home/Start Page
Elements:
- Hero section with main active offer
- Horizontal scroll carousel of featured offers (3-5 cards)
- "View All Offers" button
- Quick stats: "X Active Offers" badge

Customer Actions:
- Tap offer card → View offer details modal
- Swipe carousel → See more offers
- Tap "View All" → Navigate to offers list page

---

 Page 2: Products Page
Existing Enhanced:
- Offer badges on product cards
- Filter button: "Show Only Offers"
- Sort option: "Best Deals First"

New Elements:
- Offer badge types (color-coded)
- Strikethrough original price
- Highlighted offer price
- "Save X SAR" text

Customer Actions:
- Tap product card → View product details
- Tap offer badge → View offer details modal
- Filter by offers → See only products with offers
- Add to cart → Offer automatically applied

---

 Page 3: Product Detail (Offer Modal)
New Component:
- Full-screen modal
- Offer name and description
- Visual badge (large size)
- List of applicable products (for percentage/special price)
- BOGO rules visualization (Buy X → Get Y)
- Bundle contents breakdown
- Cart tier structure table
- Validity dates with countdown
- Terms and conditions
- "Shop Now" / "Add to Cart" button

Customer Actions:
- Scroll through details
- Tap product → Add to cart directly
- Close modal → Return to products page

---

 Page 4: Cart Page
Existing Enhanced:
- Offer indicators on each cart item
- Offer name displayed under product name
- Price comparison (was X → now Y)

New Elements:
- BOGO suggestion card (if opportunity detected)
- Bundle display (grouped items with savings)
- Cart discount progress bar
- Offer savings summary section
- Total savings badge (large, green, prominent)

Summary Section:
```
┌─────────────────────────────────┐
│ Cart Summary                    │
├─────────────────────────────────┤
│ Subtotal:            450.00 SAR │
│ 🎁 Product Offers:   -35.00 SAR │
│ 🛒 Cart Discount:    -45.00 SAR │
│ Delivery:            +15.00 SAR │
├─────────────────────────────────┤
│ TOTAL:               385.00 SAR │
│                                 │
│ 🎉 You Saved 80.00 SAR!        │
└─────────────────────────────────┘
```

Customer Actions:
- View offer details → Tap offer name
- Add BOGO product → Tap "Add Now" button
- Remove item → Removes associated offer
- Proceed to checkout

---

 Page 5: Checkout Page
Existing Enhanced:
- Order items list with offer indicators

New Elements:
- Applied Offers Card (top of page)
  - List of all offers used
  - Individual savings per offer
  - Total savings highlighted
- Final Price Breakdown
  - Line-by-line breakdown
  - Color-coded savings lines (green with minus sign)
  - Large "You Saved X SAR!" celebration message
- Offer Validation Notice
  - Real-time validation
  - Warning if offer expires during checkout
  - Automatic price update if offer becomes invalid

Customer Actions:
- Review offers applied
- Confirm order → Records usage
- If validation fails → Cart refreshed with updated prices

---

 Page 6: Bottom Cart Bar
Existing Enhanced:
- Cart count and total

New Elements:
- Savings indicator: "🎁 Saving X SAR"
- Cart offer progress bar (if applicable)
- "Add Y SAR to unlock Z% OFF" message
- Offer price vs original price display

Customer Actions:
- Tap bar → Navigate to cart
- View savings at a glance

---

 Page 7: Offers List Page (New)
New Full Page:
- Grid/list of all active offers
- Filter by type (percentage, BOGO, bundle, cart)
- Filter by branch
- Filter by expiring soon
- Search offers

Each Offer Card Shows:
- Offer name
- Offer type badge
- Discount value
- Validity dates
- "View Details" button

Customer Actions:
- Tap offer → View details modal
- Filter offers → See relevant subset
- Search → Find specific offer

---

 🎯 8. IMPLEMENTATION PHASES

 Phase 1: Foundation (Week 1)
Backend:
- Create API endpoints for offer data
- Implement offer validation logic
- Build calculation functions
- Set up usage tracking

Frontend:
- Create reusable offer badge component
- Build offer data store
- Implement calculation utilities
- Design color system and styles

Testing:
- Unit tests for calculations
- API endpoint testing
- Database query optimization

---

 Phase 2: Product Integration (Week 2)
Frontend:
- Add offer badges to product cards
- Implement offer filtering
- Create offer detail modal
- Add price comparison display

Backend:
- Optimize product-with-offers query
- Implement product-specific validation
- Add caching for better performance

Testing:
- Test product offer display
- Verify calculation accuracy
- Performance testing

---

 Phase 3: Cart & BOGO (Week 3)
Frontend:
- Enhance cart item display with offers
- Build BOGO suggestion component
- Create cart offer progress bar
- Implement bundle display

Backend:
- BOGO detection algorithm
- Bundle pricing calculation
- Cart discount calculation

Testing:
- BOGO detection scenarios
- Bundle pricing verification
- Cart discount tier testing

---

 Phase 4: Checkout & Recording (Week 4)
Frontend:
- Build offer summary card for checkout
- Implement final validation UI
- Add celebration animations
- Create savings display

Backend:
- Implement usage recording
- Build counter increment logic
- Add limit enforcement

Testing:
- End-to-end checkout flow
- Usage recording verification
- Limit enforcement testing

---

 Phase 5: Polish & Launch (Week 5)
Frontend:
- Add animations and transitions
- Implement loading states
- Add error handling UI
- Optimize mobile performance

Backend:
- Final API optimizations
- Add analytics tracking
- Implement monitoring

Testing:
- Full user acceptance testing
- Performance testing
- Security audit
- Cross-device testing

---

 📈 9. SUCCESS METRICS

 User Engagement:
- Offer View Rate: % of customers who view offer details
- Target: 70%+ view at least one offer

 Conversion:
- Offer Usage Rate: % of orders that include at least one offer
- Target: 45%+ of orders use offers

 Business Impact:
- Average Order Value: Track increase with cart discounts
- Target: 20% increase in AOV

 Customer Satisfaction:
- Savings Awareness: Customers understand how much they saved
- Target: 90%+ see savings summary

 Technical Performance:
- Page Load Time: Product page with offers
- Target: < 2 seconds

- Calculation Accuracy: No pricing errors
- Target: 100% accuracy

---

 ⚠️ 10. IMPORTANT CONSIDERATIONS

 Offer Stacking Rules:
- Product offers + Cart offers = ✅ Allowed
- Multiple product offers on same item = ❌ Not allowed (highest wins)
- BOGO + Product offer = ❌ Not allowed
- Bundle items + Individual offers = ❌ Not allowed

 Expiry Handling:
- Validate offers on every cart action
- Show countdown timer if expiring within 24 hours
- Auto-remove expired offers from cart
- Notify customer if offer expires during shopping

 Limit Enforcement:
- Check limits in real-time
- Show "X uses remaining" messaging
- Block add-to-cart if limit reached
- Clear error messages

 Branch & Service Type:
- Filter offers by customer's selected branch
- Respect delivery/pickup restrictions
- Global offers apply to all branches
- Show applicable service type icons

 Mobile Performance:
- Lazy load offer images
- Cache offer data locally
- Minimize API calls
- Optimize animations for 60fps

 Bilingual Support:
- All offer text in Arabic and English
- RTL layout for Arabic
- Cultural considerations (Friday weekend deals)
- Local currency formatting

 Error Handling:
- Graceful degradation if offers fail to load
- Clear error messages for users
- Fallback to regular prices if calculation fails
- Retry logic for network issues

---

 🎉 FINAL OUTCOME

After full implementation, customers will experience:

✅ Clear Visibility: See all applicable offers immediately
✅ Easy Understanding: Understand how much they're saving
✅ Seamless Integration: Offers apply automatically
✅ Motivation to Buy: Cart discount progress encourages higher spending
✅ Excitement: BOGO suggestions create discovery moments
✅ Trust: Transparent pricing and savings breakdown
✅ Value: Total savings prominently displayed
✅ Control: Know how many times they can use each offer

Result: Increased conversions, higher average order value, improved customer satisfaction, and measurable business growth through strategic offer deployment! 🚀
