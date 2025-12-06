# Universal RLS Policy Setup Guide

## Overview
This universal RLS policy is designed for applications using **custom authentication** (like your `persistentAuth`), not Supabase Auth.

Since your authorization is handled at the **application level**, the RLS policies simply allow all operations and rely on your app to enforce actual access control.

## What It Does

✅ **Enables RLS** on all 88 tables and storage  
✅ **Creates universal policies** that allow all operations (SELECT, INSERT, UPDATE, DELETE)  
✅ **Uses PERMISSIVE policies** with `USING (true)` and `WITH CHECK (true)`  
✅ **Grants anon role permissions** so REST API works  
✅ **Works with your custom auth** (no Supabase JWT required)

## Implementation Steps

### Step 1: Enable RLS on All Tables

Go to: https://app.supabase.com/project/urbanaqura/sql/new

Copy and paste the entire contents of `UNIVERSAL_RLS_POLICY.sql`, then click **RUN**

This will:
- Enable RLS on all tables
- Drop existing conflicting policies
- Create 4 universal policies per table (SELECT, INSERT, UPDATE, DELETE)
- Grant anon role permissions
- Verify results

### Step 2: Enable RLS on Storage

In the same SQL editor, run the contents of `UNIVERSAL_STORAGE_RLS_POLICY.sql`

This will:
- Enable RLS on storage.objects table
- Create universal storage policies
- Allow all storage operations

### Step 3: Verify Everything Works

Run this query to verify:

```sql
-- Check table RLS
SELECT 
  COUNT(*) as total_tables,
  SUM(CASE WHEN rowsecurity THEN 1 ELSE 0 END) as rls_enabled
FROM pg_tables WHERE schemaname = 'public';

-- Check storage RLS
SELECT rowsecurity FROM pg_tables WHERE tablename = 'objects';

-- Check sample policies
SELECT tablename, COUNT(*) as policy_count
FROM pg_policies WHERE schemaname = 'public'
GROUP BY tablename LIMIT 5;
```

Expected results:
```
total_tables | rls_enabled
-------------|------------
     88      |     88

-- objects table
rowsecurity
-----------
true

-- sample policies
tablename | policy_count
-----------|-------------
approvals  |      4
branches   |      4
...
```

## How It Works

| Operation | Policy | Effect |
|-----------|--------|--------|
| SELECT | `USING (true)` | ✅ Always allowed |
| INSERT | `WITH CHECK (true)` | ✅ Always allowed |
| UPDATE | `USING (true) WITH CHECK (true)` | ✅ Always allowed |
| DELETE | `USING (true)` | ✅ Always allowed |

## Security Model

- **RLS is enabled** (security layer exists)
- **All RLS policies are permissive** (don't actually restrict anything)
- **Real authorization** happens at the application level in your code
- **`persistentAuth` system** controls what users can do
- **Database is transparent** to access control

This is appropriate because:
- Your app doesn't use Supabase Auth
- Authorization is already implemented in your frontend/backend
- RLS would be redundant or incompatible with your custom auth

## If You Need Restrictive RLS Later

If you want actual RLS-level restrictions in the future:
1. You'd need to set a custom claim or context variable
2. Rewrite all policies to check that variable
3. Have your app set the variable on each request

This is complex and not recommended unless you're moving away from custom auth.

## Rollback (If Needed)

If you want to disable RLS again:

```sql
DO $$
DECLARE
  table_record RECORD;
BEGIN
  FOR table_record IN 
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE 'ALTER TABLE ' || quote_ident(table_record.tablename) || ' DISABLE ROW LEVEL SECURITY';
  END LOOP;
END
$$;
```

Then test your app to make sure everything still works.

## Testing Checklist

After implementation:
- [ ] Create a receiving record
- [ ] Create receiving tasks
- [ ] Upload clearance certificate
- [ ] Update vendor information
- [ ] Create expense requisitions
- [ ] Upload files to storage
- [ ] All operations work without permission errors
