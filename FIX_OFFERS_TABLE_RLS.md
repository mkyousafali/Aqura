# Fix: Offers Table 406 Not Acceptable Error

## Problem
When loading offers in OfferManagement component, getting:
```
GET .../offers?select=name_ar,name_en,current_total_uses 406 (Not Acceptable)
```

**Root Cause:** The `offers` table has RLS (Row Level Security) enabled but NO SELECT policies, so unauthenticated/default users cannot read it.

## Solution

**File:** `supabase/migrations/20241213_fix_offers_table_rls.sql`

This migration:
1. Enables RLS on offers table
2. Creates SELECT policy to allow reading (USING true)
3. Creates INSERT/UPDATE/DELETE policies
4. Provides verification queries

## How to Apply

### Step 1: Copy Migration
Open: `supabase/migrations/20241213_fix_offers_table_rls.sql`

### Step 2: Run in Supabase SQL Editor
1. Go to https://app.supabase.com → Aqura project
2. Click **SQL Editor** → **New Query**
3. Paste the migration code
4. Click **Run**

### Step 3: Verify
```sql
-- Run these queries to confirm:
SELECT tablename, rowsecurity FROM pg_tables WHERE tablename = 'offers';
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'offers';
```

## Expected Result
✅ Should see 4 policies on offers table:
- allow_select_offers (SELECT)
- allow_insert_offers (INSERT)
- allow_update_offers (UPDATE)
- allow_delete_offers (DELETE)

## Test
After applying:
1. Refresh browser
2. OfferManagement component should load offers without 406 errors
3. Console should show offers count > 0

## What Changed
| Component | Before | After |
|-----------|--------|-------|
| offers RLS | Enabled, no policies | Enabled, 4 policies |
| SELECT access | ❌ 406 error | ✅ Allowed |
| INSERT/UPDATE/DELETE | ❌ Blocked | ✅ Allowed |

Done! The offers should now load properly.
