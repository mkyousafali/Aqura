# Fix RLS Policies for Bundle and BOGO Offers

## Problem
The bundle offers and BOGO offers are not displaying because RLS (Row Level Security) policies are blocking anonymous users from reading the `offer_bundles` and `bogo_offer_rules` tables.

## Solution
Run the following SQL commands in **Supabase SQL Editor**:

### Step 1: Go to Supabase Dashboard
1. Open https://supabase.com/dashboard
2. Select your Aqura project
3. Click on **SQL Editor** in the left sidebar

### Step 2: Run This SQL

```sql
-- Allow public read access to offer_bundles table
DROP POLICY IF EXISTS "allow_public_read_bundles" ON offer_bundles;

CREATE POLICY "allow_public_read_bundles"
ON offer_bundles
FOR SELECT
TO anon, authenticated
USING (true);

-- Allow public read access to bogo_offer_rules table
DROP POLICY IF EXISTS "allow_public_read_bogo" ON bogo_offer_rules;

CREATE POLICY "allow_public_read_bogo"
ON bogo_offer_rules
FOR SELECT
TO anon, authenticated
USING (true);
```

### Step 3: Verify
After running the SQL, refresh the customer page and you should see:
- ✅ Bundle offers displaying in LED carousel
- ✅ BOGO offers displaying in LED carousel

### What This Does
- Creates RLS policies that allow both anonymous (`anon`) and authenticated users to **read** (SELECT) data from these tables
- `USING (true)` means no conditions - all rows are readable
- This is safe because offers are meant to be public for customers to see

### Test After Applying
Run this in browser console to verify:
```javascript
const response = await fetch('/api/customer/featured-offers');
const data = await response.json();
console.log('Bundles:', data.offers.filter(o => o.bundles?.length > 0));
console.log('BOGO:', data.offers.filter(o => o.bogo_rules?.length > 0));
```

You should see bundles and bogo_rules populated with data.
