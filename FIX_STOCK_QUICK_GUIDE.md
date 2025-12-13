# Quick: Apply Stock Adjustment Fix

## The Problem
Orders don't decrease product stock in the `products` table.

## The Fix
**File:** `supabase/migrations/20241213_fix_order_stock_adjustment.sql`

This creates a PostgreSQL trigger that automatically decreases stock when order items are added.

## How to Apply (3 Steps)

### Step 1: Copy Migration Content
Open this file in VS Code:
```
d:\Aqura\supabase\migrations\20241213_fix_order_stock_adjustment.sql
```

Copy all the SQL code.

### Step 2: Run in Supabase
1. Go to **https://app.supabase.com** → **Aqura** project
2. Click **SQL Editor** (left sidebar)
3. Click **New Query**
4. Paste the SQL code
5. Click **Run** button

### Step 3: Verify It Works
Run this test query:
```sql
-- Check trigger exists
SELECT * FROM pg_trigger 
WHERE tgname = 'trigger_adjust_product_stock';
```

If you see 1 row = ✅ Success!

## Test It

1. Note current stock of a product:
   ```sql
   SELECT current_stock FROM products WHERE id = 'PRD001';
   ```

2. Place an order for that product (10 units)

3. Check stock again:
   ```sql
   SELECT current_stock FROM products WHERE id = 'PRD001';
   ```

Should be **10 less** ✓

## What Changed

**Before:**
```
Order placed
  ↓
Stock: UNCHANGED ❌
```

**After:**
```
Order placed
  ↓
Trigger fires
  ↓
Stock: DECREASED ✓
```

## How It Works

```sql
BEFORE INSERT on order_items
  → Decrease products.current_stock by quantity
  → Then insert order item
```

Done! No other changes needed.
