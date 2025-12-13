# Customer Products Realtime Data Flow

## Database Tables Relationship

```
┌─────────────────────────────────────────────────────────────────┐
│                    CUSTOMER PRODUCTS PAGE                         │
│           src/routes/customer-interface/products                  │
└────────────────────┬────────────────────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         │           │           │
    PRODUCTS    CATEGORIES   OFFERS
       CHANNEL      CHANNEL    CHANNEL
         │           │           │
         └─────┬─────┴──────┬────┘
               │            │
        ┌──────▼────────────▼──────┐
        │   Realtime Events Flow   │
        │    (postgres_changes)    │
        └──────┬────────────────────┘
               │
         ┌─────┴──────────────────────────────┐
         │                                    │
    PRODUCTS TABLE                  OFFER RELATED TABLES
    ─────────────                   ──────────────────
    • id                            1. offer_products
    • barcode                          - Links products to offers
    • product_name_en               2. bogo_offer_rules
    • product_name_ar                  - Buy 1 Get 1 offers
    • image_url                     3. offers
    • category_id ─────────┐           - Main offer config
    • unit_id               │       4. product_categories
    • sale_price            │          - Category definitions
    • cost                  │
    • unit_qty              │
    • current_stock         │
                            └──────────┐
                                       │
                        ┌──────────────▼──────────┐
                        │  CATEGORIES/FILTERS      │
                        ├──────────────────────────┤
                        │ • id                     │
                        │ • name_en                │
                        │ • name_ar                │
                        │ • is_active              │
                        └──────────────────────────┘
```

## Event Flow Chart

```
Admin Makes Change
       │
       ▼
    ┌──────────────────────┐
    │ Product Update       │
    │ (price, stock, img)  │
    └───────┬──────────────┘
            │
            ▼
    ┌──────────────────────┐
    │ Supabase detects     │
    │ postgres_changes     │
    └───────┬──────────────┘
            │
            ▼
    ┌──────────────────────┐      
    │ Sends to clients     │
    │ subscribed via:      │
    │ .channel()           │
    └───────┬──────────────┘
            │
            ▼
    ┌──────────────────────┐
    │ Frontend receives    │
    │ change notification  │
    └───────┬──────────────┘
            │
            ▼
    ┌──────────────────────┐
    │ Triggers:            │
    │ loadProducts()       │
    │ loadCategories()     │
    └───────┬──────────────┘
            │
            ▼
    ┌──────────────────────┐
    │ API endpoint         │
    │ /api/customer/       │
    │ products-with-offers │
    └───────┬──────────────┘
            │
            ▼
    ┌──────────────────────┐
    │ Updates Svelte       │
    │ reactive store       │
    └───────┬──────────────┘
            │
            ▼
    ┌──────────────────────┐
    │ DOM auto-updates     │
    │ (reactive binding)   │
    └───────┬──────────────┘
            │
            ▼
    ┌──────────────────────┐
    │ Customer sees        │
    │ change instantly ✨   │
    │ (no refresh needed)  │
    └──────────────────────┘
```

## Table Dependencies

```
┌──────────────────────────────────────────────────────────────┐
│  PRIMARY: products (YOUR ENABLED TABLE ✓)                    │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  DEPENDS ON / RELATED TO                            │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                              │
│  1. product_categories  [❌ NOT ENABLED - NEEDS FIX]         │
│     └─> Shows category filter options                       │
│                                                              │
│  2. offer_products  [❌ NOT ENABLED - NEEDS FIX]             │
│     └─> Adds discount badges to products                    │
│     └─> Modifies prices                                     │
│                                                              │
│  3. bogo_offer_rules  [❌ NOT ENABLED - NEEDS FIX]           │
│     └─> Shows "Buy 1 Get 1" badges                          │
│     └─> Changes product display                            │
│                                                              │
│  4. offers  [❌ NOT ENABLED - NEEDS FIX]                     │
│     └─> Controls when offers are active/inactive            │
│     └─> Affects offer visibility                            │
│                                                              │
│  5. product_units  [OPTIONAL - Static mapping in code]      │
│     └─> Shows unit names (piece, dozen, etc)               │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

## Realtime Channels Configured

```
┌─────────────────────────────────────────────────────────┐
│ CHANNEL 1: products-changes                             │
├─────────────────────────────────────────────────────────┤
│ Table: products                                         │
│ Events: INSERT, UPDATE, DELETE                         │
│ Filter: branch_id (if applicable)                      │
│ Purpose: Monitor product catalog changes               │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ CHANNEL 2: offers-changes                               │
├─────────────────────────────────────────────────────────┤
│ Tables:                                                  │
│   • offer_products (INSERT, UPDATE, DELETE)            │
│   • bogo_offer_rules (INSERT, UPDATE, DELETE)          │
│   • offers (INSERT, UPDATE)                            │
│ Purpose: Monitor all offer-related changes             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ CHANNEL 3: categories-changes                           │
├─────────────────────────────────────────────────────────┤
│ Table: product_categories                              │
│ Events: INSERT, UPDATE, DELETE                         │
│ Purpose: Update category filter options                │
└─────────────────────────────────────────────────────────┘
```

## Data Update Timeline

```
Time  │  Event                    │  Frontend Action
──────┼───────────────────────────┼──────────────────────────
T0    │ Admin updates product     │ (nothing yet)
      │ price to $99              │
      │                           │
T1    │ Change committed to       │ 
      │ PostgreSQL database       │
      │                           │
T2    │ Supabase detects change   │
      │ (postgres_changes)        │
      │                           │
T3    │ Emits event to clients    │ Browser receives event
      │ via WebSocket             │ in realtime
      │                           │
T4    │                           │ "🔄 Product updated"
      │                           │ console.log triggered
      │                           │
T5    │                           │ loadProducts() called
      │                           │
T6    │                           │ API request sent to
      │                           │ /api/customer/products...
      │                           │
T7    │                           │ API returns fresh data
      │                           │ with new price $99
      │                           │
T8    │                           │ Svelte store updates
      │                           │ products array
      │                           │
T9    │                           │ DOM re-renders with
      │                           │ new price (automatic)
      │                           │
T10   │                           │ Customer sees $99 ✨
      │                           │ NO PAGE REFRESH!
      │                           │
```

## What Gets Updated When

```
Event Type           │ Table              │ Updates
─────────────────────┼────────────────────┼──────────────────
Product Added        │ products           │ Catalog list
Product Updated      │ products           │ Price, stock, image
Product Deleted      │ products           │ Catalog list
─────────────────────┼────────────────────┼──────────────────
New Offer            │ offers             │ Offer badges
Offer Updated        │ offer_products     │ Discount amount
Offer Deleted        │ offers             │ Remove badges
─────────────────────┼────────────────────┼──────────────────
BOGO Added           │ bogo_offer_rules   │ "Buy 1 Get 1" badge
BOGO Updated         │ bogo_offer_rules   │ Quantities, discount
BOGO Deleted         │ bogo_offer_rules   │ Remove BOGO badge
─────────────────────┼────────────────────┼──────────────────
Category Added       │ product_categories │ Filter options
Category Updated     │ product_categories │ Filter names
Category Deleted     │ product_categories │ Remove filter
```

## How to Verify It's Working

### Console Should Show:
```javascript
✨ New product added, reloading products...
🔄 Product updated: PRD0001
🗑️ Product deleted, reloading products...

📦 New offer product added, reloading products...
🔄 Offer product updated: OP456
📦 Offer product deleted, reloading products...

🎁 New BOGO offer created, reloading products...
🔄 BOGO offer updated: BOGO789
🎁 BOGO offer deleted, reloading products...

📊 New offer created, reloading products...
🔄 Offer updated: OFFER001

🏷️ Product categories changed, reloading categories...
```

### Network Tab Should Show:
1. WebSocket connection to Supabase (wss://...)
2. Multiple JSON-RPC messages for channel subscriptions
3. POST request to `/api/customer/products-with-offers` when change detected
4. **NO** page reload (status 200 instead of full page load)

## Next Steps

1. ✅ Frontend code updated (done)
2. ⏳ **Enable realtime for 4 tables** in Supabase Dashboard
3. ✅ Test with verification steps
4. ✅ Monitor console logs
5. ✅ (Optional) Add debouncing if needed
