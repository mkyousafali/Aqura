# Check RLS Status Query

Run this in Supabase SQL Editor to verify RLS is enabled on button tables:

```sql
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename LIKE 'button_%' OR tablename = 'branches'
ORDER BY tablename;
```

Expected result: `rowsecurity = true` for all tables

---

Also run this to verify the policies exist and are PERMISSIVE:

```sql
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  qual,
  with_check
FROM pg_policies
WHERE tablename LIKE 'button_%'
ORDER BY tablename, policyname;
```

If this returns NO ROWS for button tables, the policies weren't applied!

---

And check if any RESTRICTIVE policies are blocking INSERT:

```sql
SELECT 
  tablename,
  policyname,
  permissive,
  roles,
  qualname,
  with_check_qualname
FROM pg_policies
WHERE tablename LIKE 'button_%'
AND permissive = 'RESTRICTIVE';
```

If this returns any rows, those RESTRICTIVE policies are blocking your INSERTs!
