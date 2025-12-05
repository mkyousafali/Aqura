# RLS POLICIES IMPLEMENTATION PLAN

## Summary
Row-Level Security (RLS) policies that enforce permissions based on `role_permissions` table and user's role.

---

## Permission Model

### Permission Types in `role_permissions` table:
- `can_view` → SELECT access
- `can_add` → INSERT access  
- `can_edit` → UPDATE access
- `can_delete` → DELETE access
- `can_export` → No DB enforcement (handled in app)

### Role Hierarchy:
1. **Master Admin** - Has DELETE permission for all functions (special)
2. **Admin** - Can VIEW, ADD, EDIT, EXPORT (no DELETE)
3. **Position-based** - Permissions defined per function (configurable)

---

## RLS Policy Logic by Operation

### VIEW (SELECT) Permission
```sql
-- User can view data if they have can_view = true for that function
-- Check in role_permissions table
```

### INSERT (CREATE) Permission
```sql
-- User can insert data if they have can_add = true for that function
-- Check in role_permissions table
```

### UPDATE (EDIT) Permission
```sql
-- User can update data if they have can_edit = true for that function
-- Check in role_permissions table
```

### DELETE Permission
```sql
-- ONLY Master Admin can delete (regardless of role_permissions)
-- Check: auth.jwt() ->> 'role_type' = 'Master Admin'
```

### Branch-Level Filtering
```sql
-- Users see only data from their assigned branch
-- Check: branch_id = (SELECT branch_id FROM users WHERE id = auth.uid())
```

---

## Tables with RLS Policies

### Tier 1: Critical (Implement First)
1. **users** - Access control
   - Master Admin: Full access
   - Admin/Position-based: See only own user and team in their branch
   - Other users: See only themselves

2. **user_roles** - Role definitions
   - Master Admin: Full access
   - Others: Read-only

3. **role_permissions** - Permission management
   - Master Admin: Full access (VIEW, INSERT, UPDATE, DELETE)
   - Admin: VIEW, INSERT, UPDATE (no DELETE)
   - Position-based: No access

4. **app_functions** - Function/module list
   - All authenticated users: READ-ONLY

5. **branches** - Branch data
   - All users: READ-ONLY (for dropdown/filters)
   - Admin+ with can_edit: UPDATE own branch info

### Tier 2: Operational (After Tier 1)
6. **tasks** - Task management
   - can_view: SELECT
   - can_add: INSERT (only own branch)
   - can_edit: UPDATE (only own branch)
   - can_delete: Master Admin only
   - Branch filter: Show only user's branch tasks

7. **task_assignments** - Task assignments
   - can_view: SELECT own assignments
   - can_add: INSERT (Branch Admin only)
   - can_edit: UPDATE own assignments
   - can_delete: Master Admin only
   - Branch filter: Own branch only

8. **receiving_records** - Receiving data
   - can_view: SELECT (own branch)
   - can_add: INSERT (own branch)
   - can_edit: UPDATE (own branch)
   - can_delete: Master Admin only
   - Branch filter: Own branch only

9. **vendors** - Vendor list
   - can_view: SELECT
   - can_add: INSERT (Master Admin + Admin)
   - can_edit: UPDATE (Master Admin + Admin)
   - can_delete: Master Admin only
   - Branch filter: Company-wide (all branches can see)

10. **notifications** - Notifications
    - can_view: SELECT own + sent to user's branch
    - can_add: INSERT (Admin+ only)
    - can_edit: UPDATE status (own only)
    - can_delete: Master Admin only

### Tier 3: Storage (After Tier 2)
11. **Storage Buckets** - File access
    - task-images: Access if user has task_management > can_view
    - completion-photos: Access if user can upload tasks
    - notification-images: Access if can_view notifications
    - user-avatars: All can upload own avatar
    - others: Admin+ only

---

## Implementation Steps

### Step 1: Enable RLS on Tables
```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_functions ENABLE ROW LEVEL SECURITY;
ALTER TABLE branches ENABLE ROW LEVEL SECURITY;
-- ... etc for other tables
```

### Step 2: Create RLS Policies

#### Example: users table
```sql
-- Policy: Master Admin sees all
CREATE POLICY "master_admin_all_access" ON users
  FOR ALL
  USING (
    (SELECT role_type FROM users WHERE id = auth.uid()) = 'Master Admin'
  );

-- Policy: Users see themselves
CREATE POLICY "users_see_own" ON users
  FOR SELECT
  USING (id = auth.uid());

-- Policy: Branch admins see users in their branch
CREATE POLICY "admin_sees_branch_users" ON users
  FOR SELECT
  USING (
    branch_id = (SELECT branch_id FROM users WHERE id = auth.uid())
    AND (SELECT role_type FROM users WHERE id = auth.uid()) IN ('Master Admin', 'Admin')
  );

-- Policy: Admins can update users in their branch
CREATE POLICY "admin_update_branch_users" ON users
  FOR UPDATE
  USING (
    branch_id = (SELECT branch_id FROM users WHERE id = auth.uid())
    AND (SELECT role_type FROM users WHERE id = auth.uid()) = 'Admin'
  );

-- Policy: Only Master Admin can delete
CREATE POLICY "master_admin_delete_users" ON users
  FOR DELETE
  USING (
    (SELECT role_type FROM users WHERE id = auth.uid()) = 'Master Admin'
  );
```

#### Example: role_permissions table
```sql
-- Policy: Master Admin full access
CREATE POLICY "master_admin_full_rp" ON role_permissions
  FOR ALL
  USING (
    (SELECT role_type FROM users WHERE id = auth.uid()) = 'Master Admin'
  );

-- Policy: Admin can view
CREATE POLICY "admin_view_rp" ON role_permissions
  FOR SELECT
  USING (
    (SELECT role_type FROM users WHERE id = auth.uid()) IN ('Master Admin', 'Admin')
  );

-- Policy: Admin can insert/update
CREATE POLICY "admin_modify_rp" ON role_permissions
  FOR INSERT
  WITH CHECK (
    (SELECT role_type FROM users WHERE id = auth.uid()) IN ('Master Admin', 'Admin')
  );

CREATE POLICY "admin_update_rp" ON role_permissions
  FOR UPDATE
  USING (
    (SELECT role_type FROM users WHERE id = auth.uid()) IN ('Master Admin', 'Admin')
  );

-- Policy: Only Master Admin can delete
CREATE POLICY "master_admin_delete_rp" ON role_permissions
  FOR DELETE
  USING (
    (SELECT role_type FROM users WHERE id = auth.uid()) = 'Master Admin'
  );
```

#### Example: Permission-based access (tasks table)
```sql
-- Policy: View if user has can_view permission AND same branch
CREATE POLICY "view_tasks_by_permission" ON tasks
  FOR SELECT
  USING (
    branch_id = (SELECT branch_id FROM users WHERE id = auth.uid())
    AND EXISTS (
      SELECT 1 FROM role_permissions rp
      JOIN user_roles ur ON ur.id = rp.role_id
      JOIN users u ON u.role_type = ur.role_code
      WHERE u.id = auth.uid()
      AND rp.function_code = 'TASK_MASTER'
      AND rp.can_view = true
    )
  );

-- Policy: Insert if user has can_add permission AND same branch
CREATE POLICY "insert_tasks_by_permission" ON tasks
  FOR INSERT
  WITH CHECK (
    branch_id = (SELECT branch_id FROM users WHERE id = auth.uid())
    AND EXISTS (
      SELECT 1 FROM role_permissions rp
      JOIN user_roles ur ON ur.id = rp.role_id
      JOIN users u ON u.role_type = ur.role_code
      WHERE u.id = auth.uid()
      AND rp.function_code = 'TASK_MASTER'
      AND rp.can_add = true
    )
  );

-- Policy: Update if user has can_edit permission AND same branch
CREATE POLICY "update_tasks_by_permission" ON tasks
  FOR UPDATE
  USING (
    branch_id = (SELECT branch_id FROM users WHERE id = auth.uid())
    AND EXISTS (
      SELECT 1 FROM role_permissions rp
      JOIN user_roles ur ON ur.id = rp.role_id
      JOIN users u ON u.role_type = ur.role_code
      WHERE u.id = auth.uid()
      AND rp.function_code = 'TASK_MASTER'
      AND rp.can_edit = true
    )
  );

-- Policy: Delete ONLY Master Admin
CREATE POLICY "delete_tasks_master_admin_only" ON tasks
  FOR DELETE
  USING (
    (SELECT role_type FROM users WHERE id = auth.uid()) = 'Master Admin'
  );
```

---

## Key Design Points

✅ **Master Admin Supremacy**: Can always delete, full access to everything

✅ **Role-Based**: Permissions read from `role_permissions` table

✅ **Branch Isolation**: Users see only data from their branch

✅ **Function-Level Control**: Each function (TASK_MASTER, BRANCH_MASTER, etc.) controls access

✅ **Scalable**: New roles added to `user_roles` automatically work

✅ **Storage Protected**: Bucket policies prevent unauthorized file access

---

## Migration Path

### Phase 1: Enable & Test (This Week)
- Enable RLS on critical 5 tables
- Test with test user account
- Verify Master Admin still has full access

### Phase 2: Operational Tables (Next Week)
- Add RLS to 5 operational tables
- Test with Admin account
- Test with Position-based account

### Phase 3: Full Rollout (Week 3)
- Add RLS to remaining tables
- Enable storage bucket policies
- Full system testing

---

## Rollback Plan

If something breaks:
1. Disable RLS on affected table: `ALTER TABLE table_name DISABLE ROW LEVEL SECURITY;`
2. Drop problematic policies: `DROP POLICY policy_name ON table_name;`
3. Recreate with fixes

---

## Notes

- RLS uses `auth.uid()` to get current user ID from JWT token
- Requires user to be authenticated (not anon key)
- Service role key bypasses RLS (for admin operations)
- Performance: Each query runs policy checks (add indexes if slow)

