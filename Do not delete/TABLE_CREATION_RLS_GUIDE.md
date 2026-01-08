# Table Creation & RLS Configuration Guide

## Problem We Solved

When creating `hr_employee_master` table, we encountered **401 Unauthorized (error 42501 - permission denied)** when trying to insert/upsert data. The root cause was **RLS policies not matching the client's role**.

### Key Discovery

- Your Supabase client uses the **`anon` role** (from VITE_SUPABASE_ANON_KEY)
- RLS policies MUST grant access to `anon`, `authenticated`, AND `service_role` roles
- Without proper grants, upsert operations fail even if user is logged in

---

## Table Creation Pattern (2-Step Process)

### Step 1: Create Table Migration

Create a new migration file: `supabase/migrations/NNN_table_name.sql`

```sql
-- Create table_name table
-- Description of what this table stores

CREATE TABLE IF NOT EXISTS table_name (
  id SERIAL PRIMARY KEY,                                    -- Auto-incrementing ID
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- Foreign key to users
  branch_id INTEGER REFERENCES branches(id) ON DELETE RESTRICT,  -- Foreign key with RESTRICT
  name VARCHAR(255),                                         -- Text field
  data_json JSONB DEFAULT '{}',                             -- JSON field with default
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id)                                           -- Add UNIQUE constraints as needed
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_table_name_user_id ON table_name(user_id);
CREATE INDEX IF NOT EXISTS idx_table_name_branch_id ON table_name(branch_id);

-- Optional: Create auto-update trigger for updated_at
CREATE OR REPLACE FUNCTION update_table_name_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER table_name_timestamp_update
BEFORE UPDATE ON table_name
FOR EACH ROW
EXECUTE FUNCTION update_table_name_timestamp();
```

### Step 2: Create RLS Migration

Create a new migration file: `supabase/migrations/NNN_table_name_rls.sql`

```sql
-- Enable RLS on table_name with permissive policies (matching app pattern)

-- Enable RLS (Row Level Security)
ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow all access to table_name" ON table_name;

-- Simple permissive policy for all operations
-- This matches the pattern used in denomination_user_preferences and hr_employee_master
CREATE POLICY "Allow all access to table_name"
  ON table_name
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- Grant access to ALL roles (critical - must include anon, authenticated, service_role)
GRANT ALL ON table_name TO authenticated;
GRANT ALL ON table_name TO service_role;
GRANT ALL ON table_name TO anon;
```

---

## Working Examples in Your Codebase

### Example 1: `denomination_user_preferences` (Working ✓)
**File:** `supabase/migrations/095_denomination_user_preferences.sql`

```sql
CREATE TABLE IF NOT EXISTS denomination_user_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  default_branch_id INTEGER REFERENCES branches(id) ON DELETE SET NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

ALTER TABLE denomination_user_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all access to denomination preferences"
  ON denomination_user_preferences
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON denomination_user_preferences TO authenticated;
GRANT ALL ON denomination_user_preferences TO service_role;
GRANT ALL ON denomination_user_preferences TO anon;
```

**Used by:** [Denomination.svelte](../frontend/src/lib/components/desktop-interface/master/finance/Denomination.svelte) - Upsert works perfectly ✓

### Example 2: `hr_employee_master` (Now Working ✓)
**File:** `supabase/migrations/046_hr_employee_master.sql` + `047_hr_employee_master_rls.sql`

After fixing RLS policies to match `denomination_user_preferences` pattern, upsert now works.

---

## RLS Configuration Checklist

When creating a new table with RLS, verify:

- [ ] Table creation migration (`NNN_table_name.sql`) created
- [ ] RLS migration (`NNN_table_name_rls.sql`) created
- [ ] RLS **ENABLED** on table: `ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;`
- [ ] Policy uses `FOR ALL` with `USING (true)` and `WITH CHECK (true)`
- [ ] **CRITICAL:** All three roles are granted:
  - [ ] `GRANT ALL ON table_name TO anon;`
  - [ ] `GRANT ALL ON table_name TO authenticated;`
  - [ ] `GRANT ALL ON table_name TO service_role;`
- [ ] Migration pushed: `supabase db push`

---

## Common Mistakes to Avoid

❌ **WRONG:** Granting only to `authenticated` role
```sql
GRANT ALL ON table_name TO authenticated;  -- Missing anon and service_role
```

❌ **WRONG:** RLS disabled but not intentionally
```sql
ALTER TABLE table_name DISABLE ROW LEVEL SECURITY;  -- Only do this for debugging
```

❌ **WRONG:** Complex policy conditions that aren't needed
```sql
CREATE POLICY "user_policy" ON table_name
  FOR SELECT
  USING (auth.uid() = user_id);  -- Unnecessary complexity
```

✅ **RIGHT:** Simple permissive policy matching pattern
```sql
CREATE POLICY "Allow all access to table_name"
  ON table_name
  FOR ALL
  USING (true)
  WITH CHECK (true);

GRANT ALL ON table_name TO anon;
GRANT ALL ON table_name TO authenticated;
GRANT ALL ON table_name TO service_role;
```

---

## Upsert Operations (After RLS Properly Configured)

Once RLS is set up correctly, upsert works in Svelte components:

```typescript
const { data, error } = await supabase
  .from('table_name')
  .upsert({
    user_id: $currentUser.id,
    branch_id: 1,
    name: 'Some Name',
    data_json: { key: 'value' }
  }, {
    onConflict: 'user_id'  // Specify the unique column
  });

if (error) {
  console.error('Error:', error);
} else {
  console.log('Success!', data);
}
```

---

## Foreign Keys Best Practices

| Scenario | ON DELETE | ON UPDATE | Notes |
|----------|-----------|-----------|-------|
| User reference | CASCADE | CASCADE | Delete user → delete all their records |
| Branch reference | RESTRICT | CASCADE | Prevent deleting branch if used, but allow updates |
| Optional reference | SET NULL | CASCADE | Delete referenced → set to NULL, OK for optional links |
| Master data | NO ACTION | CASCADE | Use for reference tables that should never be deleted |

**Example:**
```sql
user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
branch_id INTEGER NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
optional_position_id UUID REFERENCES hr_positions(id) ON DELETE SET NULL
```

---

## Testing After Creation

1. **Push migration:**
   ```bash
   supabase db push
   ```

2. **Verify in Supabase Dashboard:**
   - Check table exists in `Schema Editor`
   - Verify RLS is **enabled** (toggle shows green/ON)
   - Check policies exist and have correct conditions
   - Verify all 3 roles have grants in table info

3. **Test insert in frontend:**
   ```javascript
   const { data, error } = await supabase
     .from('table_name')
     .insert({ /* data */ });
   
   if (error && error.code === '42501') {
     // RLS or permission issue - verify grants
   }
   ```

4. **Test upsert in frontend:**
   ```javascript
   const { data, error } = await supabase
     .from('table_name')
     .upsert({ /* data */ }, { onConflict: 'unique_column' });
   ```

---

## Document for Future Reference

When creating new tables in the future:
1. Use this guide as template
2. Copy Step 1 & 2 migration templates
3. Ensure RLS checklist items are completed
4. Test upsert operation works before closing task
5. Add table description to this document if unique pattern used

---

## Summary

**Before this guide:** Tables created with incomplete RLS → 401 errors on upsert

**After this guide:** Tables created with full RLS → All operations work

**Key insight:** Your app uses `anon` role client, so all tables MUST grant `anon` role access in addition to `authenticated` and `service_role`.
