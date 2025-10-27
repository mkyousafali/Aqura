# 🔧 Fix Payment Status Error - Step by Step

## Problem
The error `column "payment_status" of relation "vendor_payment_schedule" does not exist` indicates that:
- Database functions, triggers, policies, or views are still trying to access the removed `payment_status` column
- The migration didn't fully complete
- Cached definitions need to be refreshed

## Solution

### Step 1: Open Supabase SQL Editor
1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/sql
2. Click on "+ New query" or use an existing query window

### Step 2: Find Problem Functions (Optional - For Debugging)
1. Open the file: `find-problem-functions.sql`
2. Copy and run it to see which functions reference payment_status
3. This helps identify the root cause

### Step 3: Run the Comprehensive Fix Script
1. Open the file: `comprehensive-fix.sql` in this directory
2. Copy **ALL** the contents (Ctrl+A, Ctrl+C)
3. Paste into the Supabase SQL Editor
4. Click the **"Run"** button (or press Ctrl+Enter)

### Step 3: Run the Comprehensive Fix Script
1. Open the file: `comprehensive-fix.sql` in this directory
2. Copy **ALL** the contents (Ctrl+A, Ctrl+C)
3. Paste into the Supabase SQL Editor
4. Click the **"Run"** button (or press Ctrl+Enter)

### Step 4: Verify the Fix
After running, you should see output like:
```
✓ Dropped view: public.some_view
✓ Dropped policy: old_policy_name
✓ RLS policies reset
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Comprehensive Fix Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Status:
   Remaining triggers: 0
   Remaining functions: 0
   Remaining views: 0
   RLS policies count: 4
   Has payment_status column: false
   Has is_paid column: true
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ All checks passed! Database is ready.

🔄 Next steps:
   1. Restart your application server
   2. Clear browser cache (Ctrl+Shift+Delete)
   3. Hard refresh (Ctrl+F5)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 5: Restart Application & Clear Cache
**IMPORTANT:** These steps are required for the fix to work!

1. **Stop your dev server** (Ctrl+C in the terminal)
2. **Clear browser cache**:
   - Press Ctrl+Shift+Delete
   - Select "Cached images and files"
   - Click "Clear data"
3. **Restart dev server**:
   ```powershell
   cd frontend
   pnpm dev
   ```
4. **Hard refresh browser**: Ctrl+F5 or Ctrl+Shift+R

### Step 6: Test the Fix
1. Navigate to Receiving Records
2. Try generating a clearance certificate
3. The error should be gone! ✅

## What the Comprehensive Script Does

✅ **Drops all views** that reference vendor_payment_schedule  
✅ **Resets all RLS policies** with fresh, clean policies  
✅ **Removes all triggers and functions** that reference payment_status  
✅ **Refreshes schema cache** to clear any cached definitions  
✅ **Verifies** everything is clean and working  
✅ **Creates new RLS policies** that work with is_paid  

## If You Still See Errors

### 1. Check for Database Functions
Run `find-problem-functions.sql` to see if any functions still reference payment_status. If you find any, they need to be recreated without that column.

### 2. Application Cache Issues
- Close ALL browser tabs of your app
- Clear browser cache completely (Ctrl+Shift+Delete → All time)
- Restart your dev server
- Open a new incognito/private window

### 3. Database Function Needs Update
If the error persists, the database function `process_clearance_certificate_generation` likely needs to be updated. You'll need to:
1. Find the function definition (use `find-problem-functions.sql`)
2. Update it to use `is_paid` instead of `payment_status`
3. Recreate the function

---

## Quick Reference: File Purposes

- **comprehensive-fix.sql** ⭐ **USE THIS FIRST** - Complete fix for all issues
- **fix-payment-status-error.sql** - Basic fix (use if comprehensive doesn't work)
- **find-problem-functions.sql** - Diagnostic to find problem functions
- **quick-diagnostic.sql** - Quick health check
- **diagnose-triggers.sql** - Detailed trigger inspection

---

**Need Help?** All scripts are safe to run multiple times - they check before making changes.
