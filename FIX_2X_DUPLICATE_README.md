# Quick Fix: 2x Duplicate Push Notifications

## Current Status
✅ Down from 3 duplicates to 2 (progress!)  
❌ Still getting 2 push notifications instead of 1

## Root Cause
**There are still 2 triggers firing on the notifications table**

Evidence:
- 1 recipient ✅
- 1 push subscription ✅
- 2 queue entries created at exact same time ❌
- Same user, device, subscription ID ❌

## Solution

### Run this in Supabase SQL Editor:

```sql
-- Find and drop ALL push-related triggers
DO $$ 
DECLARE
    trigger_record RECORD;
BEGIN
    FOR trigger_record IN 
        SELECT DISTINCT t.tgname 
        FROM pg_trigger t
        JOIN pg_proc p ON t.tgfoid = p.oid
        WHERE t.tgrelid = 'notifications'::regclass
        AND (p.proname LIKE '%queue_push%' OR p.proname LIKE '%push%notification%')
        AND NOT t.tgisinternal
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS %I ON notifications', trigger_record.tgname);
        RAISE NOTICE 'Dropped trigger: %', trigger_record.tgname;
    END LOOP;
END $$;

-- Create ONLY ONE trigger
CREATE TRIGGER trigger_queue_push_notification
    AFTER INSERT ON notifications
    FOR EACH ROW
    WHEN (NEW.status = 'published')
    EXECUTE FUNCTION queue_push_notification_trigger();
```

### Or run the complete diagnostic script:
File: `FIX_2X_DUPLICATE.sql` (just created)

This script will:
1. Show you ALL triggers
2. Drop ALL push-related triggers
3. Create exactly 1 trigger
4. Verify the fix
5. (Optional) Test with a notification

## Test After Fix

```bash
node scripts/check-triggers.js
```

Expected result: **1 queue entry** (not 2!)

## Files Created

1. `FIX_2X_DUPLICATE.sql` - Complete fix with diagnostics
2. `scripts/analyze-2x-duplicate.js` - Analysis script (already run)
3. `check-all-triggers.sql` - SQL to check all triggers

## Why This Happens

Even though we dropped 2 triggers earlier, there might be:
- A trigger with a different name
- A trigger from an old migration
- Multiple versions of the same trigger

The `FIX_2X_DUPLICATE.sql` script finds ALL push-related triggers by looking at the function they call, not just by name.
