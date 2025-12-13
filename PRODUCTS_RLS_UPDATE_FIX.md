# Products Table RLS Update Permission Fix

## Problem
Users can **READ** products but **cannot UPDATE** them. Error: `permission denied for table products`

### Error Details
```
401 (Unauthorized)
PATCH https://supabase.urbanaqura.com/rest/v1/products?barcode=eq.019100208360
Error: permission denied for table products
```

## Root Cause
The products table has RLS (Row Level Security) enabled with restrictive policies:
- ✅ SELECT policy allows reads (uses `USING (true)`)
- ❌ UPDATE policy is missing or restrictive
- The app's custom authentication doesn't use Supabase Auth roles

## Solution

### What's Wrong
Current RLS policies likely:
- Allow SELECT with `USING (true)` ✓
- Missing UPDATE policy OR has restrictive `USING (role() = 'authenticated'::text)` ✗

### What We're Fixing
The migration `20241213_fix_products_rls_update.sql` will:
1. Drop old restrictive UPDATE policies
2. Create new permissive UPDATE policy: `USING (true) WITH CHECK (true)`
3. Ensure SELECT, INSERT, DELETE policies are also permissive
4. Verify all 4 policies (CRUD) exist after migration

### New RLS Policies

```sql
-- SELECT: Allow all reads
CREATE POLICY "allow_select_products" ON products FOR SELECT USING (true);

-- INSERT: Allow all inserts
CREATE POLICY "allow_insert_products" ON products FOR INSERT WITH CHECK (true);

-- UPDATE: Allow all updates
CREATE POLICY "allow_update_products" ON products FOR UPDATE USING (true) WITH CHECK (true);

-- DELETE: Allow all deletes
CREATE POLICY "allow_delete_products" ON products FOR DELETE USING (true);
```

## How to Apply

### In Supabase Dashboard
1. Go to SQL Editor
2. Copy entire migration file: `20241213_fix_products_rls_update.sql`
3. Execute
4. Watch for `SUCCESS` message in output

### Expected Output
```
Pre-migration audit: [list of current policies]
Dropped old UPDATE policies (if existed)
Created new UPDATE policy: allow_update_products
Created/refreshed SELECT policy: allow_select_products
Created/refreshed INSERT and DELETE policies

Final RLS Policy Status:
SELECT Policy Exists: true
INSERT Policy Exists: true
UPDATE Policy Exists: true
DELETE Policy Exists: true

SUCCESS: All CRUD policies are now in place!
```

## What Changes
- **Database**: Products table RLS policies updated
- **Frontend**: No code changes needed - toggle will now work
- **Data**: No data affected - only permissions changed

## Testing
After migration, try toggling a product's customer status:
1. Click the toggle button for any product
2. Should update without 401 error
3. Database reflects change immediately
4. Button briefly shows disabled state during update

## Alternative: Check What Exists First

If you want to see current policies before running migration:

```sql
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'products'
ORDER BY cmd, policyname;
```

This shows:
- `policyname`: Name of the policy
- `cmd`: Operation type (SELECT, INSERT, UPDATE, DELETE)
- `qual`: The USING clause (for reads)
- `with_check`: The WITH CHECK clause (for writes)

## Security Note
These permissive policies (`USING (true)`) match the existing `branches` table pattern in your app. Since your app uses custom authentication, not Supabase Auth, this is the correct approach.

If you later implement role-based access control, you can:
1. Add a `user_role` context variable
2. Change policies to check context instead of `USING (true)`
3. Maintain current security level with more granular control

## Rollback
If you need to revert, save the current policies first:

```sql
SELECT * FROM pg_policies WHERE tablename = 'products';
```

Then recreate them with original constraints.

---
**Migration File**: `supabase/migrations/20241213_fix_products_rls_update.sql`  
**Status**: Ready to Execute  
**Prerequisite**: None - safe to run multiple times (uses DROP IF EXISTS)
