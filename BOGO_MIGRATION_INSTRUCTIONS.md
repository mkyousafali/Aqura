# Buy X Get Y (BOGO) Offers Migration Instructions

## ⚠️ IMPORTANT: Run this migration in Supabase SQL Editor

The automated migration script cannot execute due to Supabase RPC limitations. Please follow these steps:

## 📋 Step-by-Step Instructions:

### 1. Open Supabase Dashboard
- Go to your Supabase project dashboard
- Navigate to **SQL Editor** in the left sidebar

### 2. Create New Query
- Click **"New Query"** button
- Copy the contents of `create-bogo-offers-table.sql`
- Paste into the SQL editor

### 3. Execute Migration
- Click **"Run"** button (or press Ctrl+Enter)
- Wait for all statements to execute successfully

### 4. Verify Migration
Run this verification query:
```sql
-- Check if table exists and is empty
SELECT COUNT(*) as total_rules FROM bogo_offer_rules;

-- Check table structure
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'bogo_offer_rules';

-- Verify offers type constraint includes 'bogo'
SELECT constraint_name, check_clause 
FROM information_schema.check_constraints 
WHERE constraint_name = 'offers_type_check';
```

## 📊 What This Migration Creates:

### 1. **bogo_offer_rules** Table
Stores individual Buy X Get Y rules with:
- `buy_product_id` - Product customer must buy (X)
- `buy_quantity` - How many of X product required
- `get_product_id` - Product customer gets discount on (Y)
- `get_quantity` - How many of Y product gets discount
- `discount_type` - 'free', 'percentage', or 'amount'
- `discount_value` - Discount amount (0 for free, 1-100 for %, or fixed amount)

### 2. **Indexes**
- Fast lookups by offer_id
- Fast lookups by buy_product_id
- Fast lookups by get_product_id

### 3. **RLS Policies**
- Authenticated users can read rules
- Service role has full access

### 4. **Triggers**
- Auto-update `updated_at` timestamp

### 5. **Offers Table Update**
- Adds 'bogo' to type enum constraint

## 🎯 Example BOGO Rule:

```sql
INSERT INTO bogo_offer_rules (
    offer_id,
    buy_product_id,
    buy_quantity,
    get_product_id,
    get_quantity,
    discount_type,
    discount_value
) VALUES (
    1,  -- offer_id
    '26c67368-5214-487b-bd65-a43abe1f4a8a',  -- buy product UUID
    2,  -- buy 2 items
    'cdeb1626-1ffd-4801-b0bd-0d1e59b2776b',  -- get product UUID
    1,  -- get 1 item
    'free',  -- discount type
    0  -- value (0 for free)
);
```

## ✅ After Migration:

1. **Create BOGO Offer** in frontend
2. **Add Rules** for Buy X Get Y combinations
3. **Test** offer application in customer app

## 🔧 Troubleshooting:

### Error: "relation bogo_offer_rules already exists"
- Table already created, skip to verification step

### Error: "constraint offers_type_check already allows bogo"
- Constraint already updated, continue with migration

### Error: "violates check constraint"
- Ensure discount_value matches discount_type rules:
  - `free`: value must be 0
  - `percentage`: value must be 1-100
  - `amount`: value must be > 0

## 📝 Database Schema:

```
offers (existing)
├── id (SERIAL)
├── type (enum: 'bundle', 'cart', 'product', 'bogo') ← UPDATED
├── name_ar, name_en
├── description_ar, description_en
├── start_date, end_date
└── ... other fields

bogo_offer_rules (NEW)
├── id (SERIAL)
├── offer_id → offers(id)
├── buy_product_id → products(id)
├── buy_quantity (INTEGER)
├── get_product_id → products(id)
├── get_quantity (INTEGER)
├── discount_type (VARCHAR)
├── discount_value (DECIMAL)
└── created_at, updated_at
```

## 🚀 Ready to Use:

After successful migration, the `BuyXGetYOfferWindow.svelte` component will be able to:
- Create offers with type='bogo'
- Add multiple Buy X Get Y rules per offer
- Save rules to `bogo_offer_rules` table
- Display saved rules in cards

---
**Next Step**: Run the SQL migration in Supabase SQL Editor
