# Fix: Approver ID Not Updating (Shows NULL)

## Problem
The `approver_id` field in the `expense_requisitions` table is always `NULL` even when an approver is selected.

## Root Cause
**Type Mismatch:**
- Migration file defines: `approver_id BIGINT` (integer)
- User IDs in the system are: `UUID` (string like "a1b2c3d4-...")
- RequestGenerator tries: `parseInt(selectedApproverId)` → Returns `NaN` → Becomes `NULL`

## Solution

### Step 1: Run SQL to Fix Column Types

Open **Supabase Dashboard** → **SQL Editor** and run:

```sql
-- Fix approver_id and created_by column types
ALTER TABLE public.expense_requisitions 
ALTER COLUMN approver_id TYPE UUID USING approver_id::TEXT::UUID;

ALTER TABLE public.expense_requisitions 
ALTER COLUMN created_by TYPE UUID USING created_by::TEXT::UUID;
```

This converts:
- `approver_id`: `BIGINT` → `UUID`
- `created_by`: `TEXT` → `UUID`

### Step 2: Verify Column Types

Run this to confirm the changes:

```sql
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'expense_requisitions'
AND column_name IN ('approver_id', 'created_by')
ORDER BY column_name;
```

Expected output:
```
approver_id  | uuid | YES
created_by   | uuid | NO
```

### Step 3: Code Changes (Already Applied)

**RequestGenerator.svelte** - Line 323:
- ❌ **Before**: `approver_id: selectedApproverId ? parseInt(selectedApproverId) : null`
- ✅ **After**: `approver_id: selectedApproverId || null`

**Migration file updated** - `007_create_expense_requisitions_table.sql`:
- ❌ **Before**: `approver_id BIGINT`
- ✅ **After**: `approver_id UUID`
- ❌ **Before**: `created_by TEXT`
- ✅ **After**: `created_by UUID`

## Testing

1. **Run the SQL fix** in Supabase Dashboard
2. **Refresh your browser** (clear cache if needed)
3. **Create a new requisition** with an approver selected
4. **Check the database** - `approver_id` should now show the UUID

Example:
```
approver_id: a1b2c3d4-e5f6-7890-abcd-ef1234567890
approver_name: madmin
```

## Files Modified

1. ✅ `supabase/migrations/007_create_expense_requisitions_table.sql` - Updated column types
2. ✅ `supabase/fix_approver_id_type.sql` - New SQL fix script
3. ✅ `frontend/src/lib/components/admin/finance/RequestGenerator.svelte` - Removed parseInt()

## Why This Happened

The original migration was designed with `BIGINT` for IDs (probably expecting numeric IDs), but your system uses **UUID-based authentication** where user IDs are UUIDs, not integers.

---

**After running the SQL fix, the approver_id will save correctly!** 🎉
