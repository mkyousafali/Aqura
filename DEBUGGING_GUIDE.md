# 🔍 Debugging Payment Status Error

## The Error Path

```
ClearanceCertificateManager.svelte
  ↓ calls
/api/receiving-tasks (POST)
  ↓ calls
supabase.rpc('process_clearance_certificate_generation', {...})
  ↓ executes
Database Function in Supabase
  ↓ ERROR HERE
column "payment_status" does not exist
```

## The Problem

The database function `process_clearance_certificate_generation` was created BEFORE the migration and still references the old `payment_status` column. Even though:
- ✅ The column has been removed from the table
- ✅ The frontend code uses `is_paid`
- ✅ The table structure is correct

The **database function** still has the old code in it.

## Solution Steps

### Step 1: Find the Problematic Function
1. Open Supabase SQL Editor
2. Run `show-problem-functions.sql`
3. This will display the function definition
4. Look for any line that mentions `payment_status`

### Step 2: Update the Function
The function needs to be **recreated** with `is_paid` instead of `payment_status`. 

**Example of what needs to change:**
```sql
-- OLD (causes error)
UPDATE vendor_payment_schedule 
SET payment_status = 'paid'
WHERE id = some_id;

-- NEW (correct)
UPDATE vendor_payment_schedule 
SET is_paid = true
WHERE id = some_id;
```

### Step 3: Drop and Recreate the Function
Once you have the function definition:

1. Copy the function code
2. Replace all `payment_status = 'paid'` with `is_paid = true`
3. Replace all `payment_status = 'pending'` with `is_paid = false`
4. Replace all `payment_status = 'scheduled'` with `is_paid = false`
5. Drop the old function:
   ```sql
   DROP FUNCTION IF EXISTS process_clearance_certificate_generation CASCADE;
   ```
6. Create the new function with your updated code

### Step 4: Run the Comprehensive Fix
After manually fixing the function, run `comprehensive-fix.sql` to clean up everything else.

## Quick Fix Alternative

If you can't find or modify the function, you can:

1. **Temporarily re-add the column**:
   ```sql
   ALTER TABLE vendor_payment_schedule 
   ADD COLUMN payment_status VARCHAR DEFAULT 'pending';
   
   -- Sync with is_paid
   UPDATE vendor_payment_schedule 
   SET payment_status = CASE WHEN is_paid THEN 'paid' ELSE 'pending' END;
   ```

2. **Create a trigger to keep them in sync**:
   ```sql
   CREATE OR REPLACE FUNCTION sync_payment_status()
   RETURNS TRIGGER AS $$
   BEGIN
     NEW.payment_status = CASE WHEN NEW.is_paid THEN 'paid' ELSE 'pending' END;
     RETURN NEW;
   END;
   $$ LANGUAGE plpgsql;
   
   CREATE TRIGGER payment_status_sync
   BEFORE INSERT OR UPDATE ON vendor_payment_schedule
   FOR EACH ROW
   EXECUTE FUNCTION sync_payment_status();
   ```

3. **Update your frontend to work with both** (already done)

This is a **workaround**, not the best solution, but will let you keep working while you properly update all database functions.

## Files to Use

1. **show-problem-functions.sql** - Shows the exact function causing the error
2. **comprehensive-fix.sql** - Cleans up policies, views, triggers
3. **FIX_INSTRUCTIONS.md** - Complete step-by-step guide

## Need the Function Fixed?

If you run `show-problem-functions.sql` and share the output, I can help you create the updated version of the function with `is_paid` instead of `payment_status`.
