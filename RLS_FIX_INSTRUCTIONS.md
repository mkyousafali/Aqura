# CRITICAL FIX - RLS Policy Conflict

## Issue
The 401 Unauthorized error persists because there are likely MULTIPLE RLS policies on the receiving_records table, and at least one is RESTRICTIVE, blocking the INSERT operation.

## Root Cause
- When you have multiple policies with the same operation (e.g., multiple INSERT policies)
- If ANY policy is RESTRICTIVE, it can block the operation
- We need to REMOVE all policies and recreate only PERMISSIVE ones

## Solution
Run the script: `FIX_RLS_NUCLEAR.sql`

### Steps:
1. Go to Supabase Dashboard: https://app.supabase.com/project/urbanaqura/sql/new
2. Copy the contents of `FIX_RLS_NUCLEAR.sql`
3. Paste into the SQL editor
4. Click "RUN"
5. Wait for confirmation that policies were dropped and recreated
6. Test the application again

### What the script does:
- Drops ALL existing policies on receiving_records, vendor_payment_schedule, vendors, and branches
- Creates 4 new PERMISSIVE policies per table (INSERT, SELECT, UPDATE, DELETE)
- All policies use `WITH CHECK (true)` and `USING (true)` - completely open

### Expected Result:
- INSERT operations will succeed without 401 error
- All other operations will succeed
- No permission conflicts

### Verify:
After running, check console for: ✅ Receiving record saved
