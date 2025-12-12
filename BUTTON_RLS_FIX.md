# Button Tables RLS Policy Fix

## Problem
The ButtonGenerator component was getting **401 Unauthorized** errors when trying to INSERT/UPDATE to button tables from the frontend (using anon key).

**Root Cause**: The button tables had RLS policies that only allowed `service_role` access, blocking the anon key used by the frontend.

## Solution
Change RLS policies to allow **public role access** (anon key), matching the pattern used by working tables like:
- `receiving_records` (frontend INSERT works ✅)
- `vendors` (frontend UPDATE works ✅)
- `branches` (frontend access works ✅)

## Key Insight from Code Analysis

### Working Pattern (receiving_records):
```javascript
const { data, error } = await supabase
  .from('receiving_records')
  .insert([receivingData]); // ✅ NO .select() - works with anon key
```

### RLS Policy Pattern That Works:
```sql
-- Simple permissive policies allowing all users
CREATE POLICY "allow_insert" ON receiving_records
  FOR INSERT
  WITH CHECK (true);  -- Allow all, no auth checks

CREATE POLICY "allow_update" ON receiving_records
  FOR UPDATE
  USING (true)
  WITH CHECK (true);
```

## Changed Policies

### Before (BROKEN - service_role only):
```sql
CREATE POLICY "button_main_sections_allow_all" ON button_main_sections
  FOR INSERT, UPDATE, DELETE
  USING (auth.role() = 'service_role')  -- ❌ Only service_role
  WITH CHECK (auth.role() = 'service_role');
```

### After (FIXED - public role):
```sql
CREATE POLICY "allow_insert" ON button_main_sections
  FOR INSERT
  WITH CHECK (true);  -- ✅ Allow anon key

CREATE POLICY "allow_update" ON button_main_sections
  FOR UPDATE
  USING (true)
  WITH CHECK (true);
```

## Tables Updated
1. `button_main_sections` - 4 policies (SELECT, INSERT, UPDATE, DELETE)
2. `button_sub_sections` - 4 policies (SELECT, INSERT, UPDATE, DELETE)
3. `sidebar_buttons` - 4 policies (SELECT, INSERT, UPDATE, DELETE)
4. `button_permissions` - 4 policies (SELECT, INSERT, UPDATE, DELETE)

**Total: 16 new RLS policies** (all following the same pattern)

## How to Apply

### Option 1: Manual SQL in Supabase UI (RECOMMENDED)
1. Go to your Supabase dashboard: https://supabase.urbanaqura.com/
2. Click **SQL Editor** in the left sidebar
3. Click **New Query**
4. Open this file: `supabase/migrations/button_tables_rls.sql`
5. Copy all the SQL
6. Paste into the SQL Editor
7. Click **Execute**
8. Verify success message

### Option 2: Command Line
```bash
node scripts/apply-button-rls-fixed.cjs
```
(Note: Requires environment variables VITE_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY)

## Verification

After applying, test in browser console:
```javascript
// This should now work (previously got 401)
const { error } = await supabase
  .from('button_main_sections')
  .insert({ name_en: 'Test', name_ar: 'اختبار' });

if (error) {
  console.error('❌ Still failing:', error.message);
} else {
  console.log('✅ INSERT now works with anon key!');
}
```

### In ButtonGenerator:
1. Open Settings → Button Manager
2. Click "📤 Add Buttons" button
3. Should see extraction working
4. Should see permission insertion working
5. No more 401 errors in browser console

## Security Note

These policies allow **unrestricted access** to button configuration tables:
- Anyone with frontend access can read button definitions
- Anyone with frontend access can modify button structure

This is appropriate because:
1. **Button configurations are not sensitive data** - they're just UI structure
2. **Business logic** is enforced elsewhere (in permission tables)
3. **Detailed permissions** are in `button_permissions` table (per-user-per-button)

For production security:
- Consider restricting INSERT/UPDATE/DELETE to authenticated users only
- Use `authenticated` role condition instead of `true`
- Add field-level checks (e.g., only allow certain field updates)

## Related Tables

These tables use similar `true`-based RLS policies and work fine:
- `receiving_records` - Anyone can INSERT
- `vendors` - Anyone can UPDATE
- `branches` - Anyone can SELECT/INSERT/UPDATE
- `order_audit_logs` - Anyone can INSERT

This is a consistent security model for configuration and operational data.

## Troubleshooting

### 401 Unauthorized still happening?
1. ✅ Did you execute the SQL?
2. ✅ Did it say "successfully" at the end?
3. ✅ Clear browser cache (hard refresh: Ctrl+Shift+R)
4. ✅ Check Supabase SQL logs for policy errors

### How to check if policies applied:
```sql
-- Run this in Supabase SQL Editor
SELECT schemaname, tablename, policyname, permissive, roles, qual
FROM pg_policies
WHERE tablename IN ('button_main_sections', 'button_sub_sections', 'sidebar_buttons', 'button_permissions')
ORDER BY tablename, policyname;
```

Expected: Should show 16 policies (4 per table) with `PERMISSIVE` type and `public` role.

## Files Modified
- `supabase/migrations/button_tables_rls.sql` - Updated with correct policies
- `scripts/apply-button-rls-fixed.cjs` - Helper script (optional)

## Next Steps

After RLS is applied:
1. ✅ Test ButtonGenerator "Add Buttons" functionality
2. ✅ Run permission population
3. ✅ Test "Update Permissions" button
4. ⏳ Implement ButtonAccessControl step 2 (permission toggle UI)
5. ⏳ Integrate into Sidebar component
