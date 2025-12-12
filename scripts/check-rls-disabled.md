# Quick Check: Is branches table RLS disabled?

Run this in Supabase SQL Editor:

```sql
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename IN ('branches', 'button_main_sections', 'button_sub_sections', 'sidebar_buttons', 'button_permissions')
ORDER BY tablename;
```

**Expected for branches:** `rowsecurity = false` (RLS is OFF - that's why it works!)
**Expected for buttons:** `rowsecurity = true` (RLS is ON - and policies might be blocking)

---

If branches has `rowsecurity = false`, then the solution is simple:
1. **Disable RLS on button tables** - Just like branches
2. OR **Remove all policies and let tables be fully accessible**

Which one would you prefer?
