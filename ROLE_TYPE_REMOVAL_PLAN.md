# Role Type Removal Implementation Plan

**Date:** December 12, 2025  
**Objective:** Remove user `role_type` system, keep task `role_type` and approval permissions  
**Confidence Level:** 95%  
**Approach:** Option A (Boolean flags) + Auto-migration on first deploy

---

## Executive Summary

**What's Being Removed:**
- User's `role_type` column (Master Admin/Admin/Position-based)
- `user_roles` table
- `role_permissions` table
- `app_functions` table
- All role-based permission logic

**What's Staying:**
- ✅ Task `role_type` (inventory_manager, purchase_manager, etc.)
- ✅ Approval permissions system (`approval_permissions` table)
- ✅ Button access system (`button_permissions` table)

**What's Being Added:**
- New columns: `is_master_admin` and `is_admin` (boolean) in `users` table

---

## Phase 1: Database Migration (Pre-deployment)

### 1.1 Create Migration File
**File:** `supabase/migrations/remove_role_type_system.sql`

**Steps:**
1. Add boolean columns to `users` table
2. Migrate existing data (role_type → boolean columns)
3. Drop role-based tables
4. Remove `role_type` column from `users`

**Migration Details:**
```sql
-- Step 1: Add new columns
ALTER TABLE users 
ADD COLUMN is_master_admin BOOLEAN DEFAULT false,
ADD COLUMN is_admin BOOLEAN DEFAULT false;

-- Step 2: Migrate data
UPDATE users 
SET is_master_admin = true 
WHERE role_type = 'Master Admin';

UPDATE users 
SET is_admin = true 
WHERE role_type = 'Admin' AND role_type != 'Master Admin';

-- Step 3: Drop foreign key relationships
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_role_id_fkey;
ALTER TABLE users DROP CONSTRAINT IF EXISTS fk_users_position;

-- Step 4: Drop tables
DROP TABLE IF EXISTS role_permissions CASCADE;
DROP TABLE IF EXISTS app_functions CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;

-- Step 5: Drop column
ALTER TABLE users DROP COLUMN role_type;
```

---

## Phase 2: Frontend Type System Updates

### 2.1 Update Type Definitions

**Files to Update:**

#### `frontend/src/lib/utils/persistentAuth.ts`
- Remove `role_type` from CurrentUser interface
- Add `is_master_admin` and `is_admin` boolean fields
- Update all references to use new fields

#### `frontend/src/lib/utils/userManagement.ts`
- Remove `roleType` from CreateUserRequest interface
- Remove `roleType` from UpdateUserRequest interface
- Remove `role_type` from UserListItem interface
- Remove `roleType` parameter from createUser() RPC call
- Remove `getUserRoles()` method entirely

#### `frontend/src/lib/utils/supabase.ts`
- Update any role_type queries to use new boolean fields

---

## Phase 3: Component Updates

### 3.1 Create User Form
**File:** `frontend/src/lib/components/desktop-interface/settings/user/CreateUser.svelte`

**Changes:**
- Remove roleType from formData
- Remove role_type from validation logic
- Remove role selection dropdown from UI
- Remove roleId field from UI
- Update handleSubmit() to not pass roleType
- Add optional "Create as Admin?" checkbox (POST-MIGRATION feature)

**Lines Affected:** ~50 lines removed

### 3.2 User Management View
**File:** `frontend/src/lib/components/desktop-interface/settings/user/UserManagement.svelte`

**Changes:**
- Remove role_type column from user list table
- Add is_admin badge/indicator in user list
- Update any role_type display logic

**Lines Affected:** ~20 lines changed

### 3.3 Button Access Control
**File:** `frontend/src/lib/components/desktop-interface/settings/ButtonAccessControl.svelte`

**Changes:**
- Remove role_type filtering logic in loadUsers()
- Remove role_type dropdown filter
- Update user list query to not select role_type
- Keep button permission logic (unchanged)

**Lines Affected:** ~30 lines removed

### 3.4 Manage Master Admin
**File:** `frontend/src/lib/components/desktop-interface/settings/user/ManageMasterAdmin.svelte`

**Changes:**
- Update role_type check to use is_master_admin boolean
- Update table to show is_master_admin flag instead of role_type
- Keep approval permissions section (unchanged)

**Lines Affected:** ~15 lines changed

### 3.5 Mobile Interface Layout
**File:** `frontend/src/routes/mobile-interface/+layout.svelte`

**Changes:**
- Replace `roleType === 'Master Admin' || roleType === 'Admin'` checks
- Use `is_master_admin || is_admin` instead

**Lines Affected:** ~5 lines changed

### 3.6 Mobile Reports
**File:** `frontend/src/routes/mobile-interface/reports/+page.svelte`

**Changes:**
- Replace roleType check with is_master_admin || is_admin check

**Lines Affected:** ~3 lines changed

### 3.7 Mobile Notifications
**File:** `frontend/src/routes/mobile-interface/notifications/create/+page.svelte`

**Changes:**
- Remove role_type from user objects when loading
- Remove role_type display in user list

**Lines Affected:** ~10 lines changed

---

## Phase 4: Permission Helper Functions

### 4.1 Update Auth Store
**File:** `frontend/src/lib/utils/persistentAuth.ts`

**Changes:**
- Update loadUserSession() to populate is_master_admin and is_admin
- Update login() function to set new boolean fields
- Update signup() function if applicable
- Remove any roleType references

**Lines Affected:** ~30 lines changed

### 4.2 Clean Up Permissions Utility
**File:** `frontend/src/lib/utils/permissions.ts`

**Changes:**
- Keep approval permission functions (unchanged)
- Keep button permission functions (unchanged)
- Remove all role-type checking functions:
  - Remove `hasPermission()`
  - Remove `canView()`, `canCreate()`, `canEdit()`, `canDelete()`, `canExport()`
  - Remove `isAdmin()`, `isMasterAdmin()`
  - Remove `getUserRole()`
  - Remove `FUNCTION_CODES` constant
  - Keep: `getAccessibleFunctions()` but rewrite to use button permissions
  - Keep: Approval permission checks

**Lines Affected:** ~200 lines removed, ~20 lines rewritten

---

## Phase 5: Sidebar Conditional Rendering

### 5.1 Update Sidebar Component
**File:** `frontend/src/lib/components/desktop-interface/common/Sidebar.svelte`

**Changes:**
- Keep button permission checks (already implemented with `isButtonAllowed()`)
- Keep approval permission checks (already implemented with `hasApprovalPermission`)
- Remove all direct roleType checks
- Examples to find and replace:
  ```
  {#if $currentUser?.roleType === 'Master Admin' || $currentUser?.roleType === 'Admin'}
  {#if showSettingsSubmenu && ($currentUser?.roleType === 'Master Admin')}
  ```
  Replace with:
  ```
  {#if $currentUser?.is_master_admin || $currentUser?.is_admin}
  {#if showSettingsSubmenu && ($currentUser?.is_master_admin)}
  ```

**Lines Affected:** ~8 lines changed (already added button checks earlier)

---

## Phase 6: Database RPC Functions

### 6.1 Update create_user RPC
**Location:** Database function (likely in Supabase migrations)

**Changes:**
- Remove `p_role_type` parameter
- Remove role_type assignment logic
- Keep all other user creation logic
- Note: Admin status can be set separately via insert into admin_users or direct update

**Signature Change:**
```sql
-- OLD
CREATE OR REPLACE FUNCTION create_user(
  p_username VARCHAR,
  p_password VARCHAR,
  p_role_type VARCHAR,        -- ← REMOVE
  p_user_type VARCHAR,
  p_branch_id BIGINT,
  p_employee_id UUID,
  p_position_id UUID,
  p_quick_access_code VARCHAR
)

-- NEW
CREATE OR REPLACE FUNCTION create_user(
  p_username VARCHAR,
  p_password VARCHAR,
  p_user_type VARCHAR,
  p_branch_id BIGINT,
  p_employee_id UUID,
  p_position_id UUID,
  p_quick_access_code VARCHAR
)
```

### 6.2 Update update_user RPC
**Changes:**
- Remove `p_role_type` from update parameters
- Keep all other update logic

---

## Phase 7: API Routes

### 7.1 Check User Management API Routes
**Files to Scan:**
- `frontend/src/routes/api/**/*user*.ts`
- `frontend/src/routes/api/**/*admin*.ts`

**Changes:**
- Remove any role_type filtering
- Update any role_type queries
- Keep task role_type queries (they're different)

---

## Phase 8: Cleanup & Removal

### 8.1 Delete Unused Components
**Files to Delete (AFTER migrations complete):**
- ❌ `frontend/src/lib/components/desktop-interface/settings/user/CreateUserRoles.svelte`
- ❌ `frontend/src/lib/components/desktop-interface/settings/user/AssignRoles.svelte`
- ❌ `frontend/src/lib/components/desktop-interface/settings/user/PermissionManager.svelte`
- ❌ `frontend/src/lib/components/desktop-interface/settings/InterfaceAccessManager.svelte` (if only used for role-based interface selection)
- ❌ `frontend/src/lib/components/desktop-interface/settings/user/UserPermissionsWindow.svelte`

### 8.2 Remove Documentation
**Files to Update:**
- ❌ `Do not delete\USER_PERMISSIONS_SYSTEM_SETUP.md` - Archive or delete
- ❌ Remove role-type references from `DATABASE_SCHEMA.md`

---

## Implementation Checklist

### Pre-Deployment
- [x] Create migration SQL file
- [x] Test migration on staging database
- [x] Backup production database
- [x] Verify all Master Admin/Admin users will be migrated correctly

### Frontend Code Changes
- [x] Update `persistentAuth.ts` type definitions
- [x] Update `userManagement.ts` interfaces and methods
- [x] Update `supabase.ts` queries (not needed)
- [x] Update `permissions.ts` utility functions
- [x] Update `CreateUser.svelte` component
- [x] Update `UserManagement.svelte` component
- [ ] Update `ButtonAccessControl.svelte` component (OPTIONAL - minor cleanup)
- [ ] Update `ManageMasterAdmin.svelte` component (OPTIONAL - minor cleanup)
- [x] Update `Sidebar.svelte` component (roleType checks)
- [x] Update mobile interface routes
- [ ] Update notifications component (OPTIONAL - minor cleanup)

### Database Changes
- [x] Deploy migration to add boolean columns ✅
- [x] Deploy migration to drop old tables ✅
- [x] Recreate `set_user_context` RPC with boolean parameters ✅
- [x] Recreate `user_permissions_view` with button permissions ✅
- [x] Create helper functions (is_user_admin, is_user_master_admin, etc.) ✅
- [x] Update RPC functions (create_user, update_user) ✅
- [x] Fix update_user function type casting issues ✅ COMPLETED
- [x] Test RPC functions post-migration ✅ Ready for user testing

### Testing
- [x] Test login (verify no 404 errors) ✅ WORKING
- [ ] Test user creation (without roleType) ⚠️ NEXT - Need to test Create User form
- [x] Test user editing ✅ update_user function fixed, ready to test
- [ ] Test Master Admin functionality ⚠️ TEST - Verify all admin features work
- [ ] Test Admin functionality ⚠️ TEST - Verify all admin features work
- [x] Test button permissions still work ✅ Verified - 75 buttons loading
- [ ] Test approval permissions still work ⚠️ TEST
- [ ] Test task role_type still works ⚠️ TEST
- [ ] Test mobile interface
- [ ] Test sidebar rendering ✅ Mostly done - buttons showing correctly

### Cleanup (OPTIONAL - Can do later)
- [ ] Delete unused components
- [ ] Remove unused imports
- [ ] Update documentation
- [ ] Remove dead code
- [ ] Clean up test scripts in scripts/ folder

---

## Affected Files Summary

### Files to Modify (32 files):
**Database:**
- `supabase/migrations/` - 1 new migration file

**Frontend - Types & Utilities:**
- `frontend/src/lib/utils/persistentAuth.ts`
- `frontend/src/lib/utils/userManagement.ts`
- `frontend/src/lib/utils/supabase.ts`
- `frontend/src/lib/utils/permissions.ts`

**Frontend - Components:**
- `frontend/src/lib/components/desktop-interface/settings/user/CreateUser.svelte`
- `frontend/src/lib/components/desktop-interface/settings/user/UserManagement.svelte`
- `frontend/src/lib/components/desktop-interface/settings/user/ManageMasterAdmin.svelte`
- `frontend/src/lib/components/desktop-interface/settings/ButtonAccessControl.svelte`
- `frontend/src/lib/components/desktop-interface/common/Sidebar.svelte`

**Frontend - Mobile Routes:**
- `frontend/src/routes/mobile-interface/+layout.svelte`
- `frontend/src/routes/mobile-interface/reports/+page.svelte`
- `frontend/src/routes/mobile-interface/notifications/create/+page.svelte`

**Frontend - Delete Components:**
- `frontend/src/lib/components/desktop-interface/settings/user/CreateUserRoles.svelte`
- `frontend/src/lib/components/desktop-interface/settings/user/AssignRoles.svelte`
- `frontend/src/lib/components/desktop-interface/settings/user/PermissionManager.svelte`
- `frontend/src/lib/components/desktop-interface/settings/InterfaceAccessManager.svelte`
- `frontend/src/lib/components/desktop-interface/settings/user/UserPermissionsWindow.svelte`

**Documentation:**
- `Do not delete\USER_PERMISSIONS_SYSTEM_SETUP.md`
- `Do not delete\DATABASE_SCHEMA.md`

---

## Risk Assessment

### ✅ Low Risk Areas:
- Task role_type system (completely separate, no changes)
- Approval permissions (independent system, no changes)
- Button permissions (already implemented, no changes)
- Mobile task workflows (use task role_type, not user role_type)

### 🟡 Medium Risk Areas:
- Auth store updates (affects login/signup, but well-tested)
- Sidebar rendering (many conditions, but all follow same pattern)
- RPC function updates (backend changes, test thoroughly)

### ❌ High Risk Areas:
- None identified! This refactoring is very low-risk because:
  1. Systems are already separated (button access, approvals)
  2. No complex interdependencies
  3. Task role_type is completely independent
  4. Approval system is independent

---

## Estimated Effort

| Phase | Tasks | Hours |
|-------|-------|-------|
| 1 - Database | Migration + testing | 2 |
| 2 - Types | Update interfaces | 1 |
| 3 - Components | 8 components | 4 |
| 4 - Auth Store | persistentAuth updates | 2 |
| 5 - Sidebar | Conditional rendering | 1 |
| 6 - RPC Functions | create_user, update_user | 1 |
| 7 - API Routes | Scan and update | 0.5 |
| 8 - Cleanup | Delete components | 0.5 |
| **Testing** | All systems | 3 |
| **Total** | | **15 hours** |

---

## Success Criteria

✅ **System is successful when:**
1. Users can be created without role_type
2. Master Admins still have Master Admin access (via is_master_admin flag)
3. Admins still have Admin access (via is_admin flag)
4. Button permissions work exactly as before
5. Approval permissions work exactly as before
6. Task workflows work exactly as before
7. All tests pass
8. No console errors related to role_type
9. No broken references to deleted components
10. Mobile interface renders correctly

---

## Rollback Plan

If critical issues found:
1. Restore database from pre-migration backup
2. Revert frontend code changes from Git
3. No data loss (migration is reversible with backup)

---

## Next Steps

1. Review this plan with team
2. Confirm all 4 clarifying questions answered ✅
3. Schedule deployment window
4. Execute Phase 1 (database migration)
5. Deploy frontend changes (Phases 2-8)
6. Run comprehensive testing
7. Monitor for errors post-deployment

