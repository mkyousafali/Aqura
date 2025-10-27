# Fix: Approval Center Shows "No Requisitions Found"

## Problem
The Approval Center displays "No Requisitions Found" even though data exists in the `expense_requisitions` table.

## Root Cause
The `expense_requisitions` table has **Row Level Security (RLS) enabled** but **NO POLICIES** defined. This blocks all read access for authenticated users.

From migration `007_create_expense_requisitions_table.sql`:
```sql
ALTER TABLE public.expense_requisitions ENABLE ROW LEVEL SECURITY;
-- ❌ No policies defined!
```

## Solution

### Option 1: Run SQL Fix (Recommended)
1. Go to your **Supabase Dashboard**
2. Navigate to **SQL Editor**
3. Open the file: `supabase/fix_expense_requisitions_rls.sql`
4. Copy and paste the SQL into the editor
5. Click **Run**

### Option 2: Disable RLS (Not Recommended for Production)
If you want to temporarily disable RLS for testing:

```sql
ALTER TABLE public.expense_requisitions DISABLE ROW LEVEL SECURITY;
```

### Option 3: Use Supabase Admin Client
Update your frontend code to use the admin client for this specific query (if you have service role key):

```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseAdmin = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
)
```

## Verification

After applying the fix, check in Supabase Dashboard:

1. Go to **Authentication** → **Policies**
2. Find `expense_requisitions` table
3. You should see 4 policies:
   - ✅ "Allow authenticated users to read expense requisitions"
   - ✅ "Allow authenticated users to create expense requisitions"
   - ✅ "Allow authenticated users to update expense requisitions"
   - ✅ "Service role has full access to expense requisitions"

## Test
1. Refresh the Approval Center
2. Console should show:
   ```
   ✅ User has approval permissions: [username] Limit: [amount]
   🔍 Fetching requisitions from expense_requisitions table...
   📊 Query result: { data: [...], error: null, count: X }
   ✅ Loaded requisitions: X
   ```
3. Requisitions should now be visible in the table

## What the Policies Do

- **SELECT Policy**: Allows all authenticated users to read requisitions
- **INSERT Policy**: Allows all authenticated users to create requisitions
- **UPDATE Policy**: Allows all authenticated users to update requisitions (approve/reject)
- **Service Role Policy**: Gives full access to backend/admin operations

## Optional: More Restrictive Policies

If you want to restrict access based on user permissions, you can modify the policies:

```sql
-- Example: Only users with can_approve_payments can read
CREATE POLICY "Only approvers can read expense requisitions"
ON public.expense_requisitions
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid()
    AND users.can_approve_payments = true
  )
);
```

## Files Modified
- ✅ `supabase/migrations/007_create_expense_requisitions_table.sql` - Updated with RLS policies
- ✅ `supabase/fix_expense_requisitions_rls.sql` - New SQL fix script
- ✅ `frontend/src/lib/components/admin/finance/ApprovalCenter.svelte` - Added debugging logs

---

**After applying the fix, the Approval Center should work correctly! 🎉**
