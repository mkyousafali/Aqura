# Employee User Function Access System - Current State Analysis

**Date:** December 1, 2025  
**Status:** Analysis Complete  
**Purpose:** Document current state before implementing unified access control system

---

## Executive Summary

The Aqura system currently has **two parallel permission systems** that need to be unified:

1. **Role-Based Permission System** (Partially Implemented)
   - Database tables: `app_functions`, `role_permissions`, `user_roles`
   - 43 system functions defined
   - Permission types: view, add, edit, delete, export
   
2. **Hardcoded Access Checks** (Throughout Codebase)
   - Direct role_type comparisons: `Master Admin`, `Admin`, `Position-based`
   - Task-specific role checks: `inventory_manager`, `purchase_manager`, etc.
   - Interface permissions (separate system already working)

---

## 1. Current Database Schema

### Permission-Related Tables

#### 1.1 `app_functions` (System Functions)
**Status:** ✅ Exists, 43 functions defined  
**Columns:**
- `id` (uuid)
- `function_name` (varchar)
- `function_code` (varchar) - e.g., 'DASHBOARD', 'USER_MGMT'
- `description` (text)
- `category` (varchar) - e.g., 'User Management', 'Reports'
- `is_active` (boolean)
- `created_at`, `updated_at`

**Purpose:** Defines all system functions/features that can have permissions assigned

---

#### 1.2 `role_permissions` (Function Access Control)
**Status:** ⚠️ Exists but incomplete (only 12 records exist, need 86+)  
**Columns:**
- `id` (uuid)
- `role_id` (uuid) → references `user_roles.id`
- `function_id` (uuid) → references `app_functions.id`
- `can_view` (boolean)
- `can_add` (boolean)
- `can_edit` (boolean)
- `can_delete` (boolean)
- `can_export` (boolean)
- `created_at`, `updated_at`

**Purpose:** Maps roles to functions with granular permissions

**Current Gap:** Only 12 permission records exist, but with 43 functions × 2 roles (Master Admin + Admin) = should have 86 records minimum

---

#### 1.3 `user_roles` (Role Definitions)
**Status:** ✅ Exists  
**Columns:**
- `id` (uuid)
- `role_name` (varchar) - Display name
- `role_code` (varchar) - Code like 'MASTER_ADMIN', 'ADMIN'
- `description` (text)
- `is_system_role` (boolean)
- `is_active` (boolean)
- `created_at`, `updated_at`

**Purpose:** Defines all available roles in the system

**Known Roles:**
- `MASTER_ADMIN` - Full system access
- `ADMIN` - Most access except delete
- Custom position-based roles

---

#### 1.4 `users` (User Accounts)
**Status:** ✅ Exists  
**Key Permission Columns:**
- `role_type` (enum): 'Master Admin' | 'Admin' | 'Position-based' | 'Customer'
- `user_type` (enum): 'global' | 'branch_specific' | 'customer'
- `position_id` (uuid) - For position-based users
- `employee_id` (uuid)
- `branch_id` (bigint)

---

#### 1.5 `interface_permissions` (Desktop/Mobile Interface Access)
**Status:** ✅ Already working correctly  
**Columns:**
- `id` (uuid)
- `user_id` (uuid)
- `can_access_desktop_interface` (boolean)
- `can_access_mobile_interface` (boolean)
- `can_access_customer_app` (boolean)
- And more...

**Note:** This system is separate and working - DO NOT MODIFY

---

#### 1.6 `approval_permissions` (Approval Workflow Permissions)
**Status:** ✅ Already working correctly  
**Purpose:** Controls approval limits for requisitions, bills, payments, leave
**Columns:**
- `user_id` (uuid)
- `can_approve_requisitions` (boolean)
- `requisition_amount_limit` (numeric)
- `can_approve_single_bill` (boolean)
- And more approval-specific fields...

**Note:** This system is separate and working - DO NOT MODIFY

---

## 2. Hardcoded Access Restrictions Found

### 2.1 Desktop Interface Hardcoded Checks

#### Location: `frontend/src/lib/components/desktop-interface/`

**Found 20+ instances of:**
```typescript
// Pattern 1: Direct role_type comparison
$: isMasterAdmin = userRole === 'Master Admin';
$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

// Pattern 2: Current user role_type check
if (currentUser.role_type === 'Master Admin') {
    // Allow action
}

// Pattern 3: Permission flags based on role
$: canCreateRoles = currentUser.role_type === 'Master Admin' || 
                    currentUser.role_type === 'Admin';
```

**Files Affected:**
- `settings/UserManagement.svelte`
- `settings/user/CreateUserRoles.svelte`
- `settings/user/AssignRoles.svelte`
- `settings/user/EditUser.svelte`
- `settings/user/ManageAdminUsers.svelte`
- `settings/user/ManageMasterAdmin.svelte`
- `settings/ApprovalPermissionsManager.svelte`
- `master/CommunicationCenter.svelte`
- `master/communication/NotificationCenter.svelte`
- `master/communication/CreateNotification.svelte`
- `master/finance/MonthDetails.svelte`
- `master/finance/reports/ExpenseTracker.svelte`
- `master/operations/receiving/ReceivingRecords.svelte`
- `master/tasks/BranchPerformanceWindow.svelte`

---

### 2.2 Mobile Interface Hardcoded Checks

#### Location: `frontend/src/routes/mobile-interface/`

**Found 15+ instances of:**
```typescript
// Pattern 1: Admin or Master check
$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';

// Pattern 2: Reports page restriction
const userRole = $currentUser?.roleType;
if (userRole !== 'Master Admin' && userRole !== 'Admin') {
    goto('/mobile-interface');
    return;
}

// Pattern 3: Dashboard access
$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin';
```

**Files Affected:**
- `mobile-interface/+page.svelte` (Dashboard)
- `mobile-interface/reports/+page.svelte`
- `mobile-interface/notifications/create/+page.svelte`
- `lib/components/mobile-interface/notifications/NotificationCenter.svelte`

---

### 2.3 Task Role-Type Checks (Business Logic - Keep These)

#### Location: `frontend/src/routes/mobile-interface/tasks/` and receiving tasks

**Found patterns:**
```typescript
// These are BUSINESS LOGIC, not permission checks - DO NOT MODIFY
if (task.role_type === 'inventory_manager') { ... }
if (task.role_type === 'purchase_manager') { ... }
if (task.role_type === 'shelf_stocker') { ... }
if (task.role_type === 'branch_manager') { ... }
if (task.role_type === 'night_supervisor') { ... }
if (task.role_type === 'accountant') { ... }
```

**Purpose:** These determine task workflows and dependencies, NOT user permissions

**Decision:** ✅ **KEEP THESE** - They are part of the receiving workflow business logic

---

## 3. Current Permission Systems (Working)

### 3.1 Interface Permissions ✅ 
**Table:** `interface_permissions`  
**Status:** Working correctly  
**Controls:** Desktop/Mobile/Customer app access per user  
**Action:** DO NOT MODIFY

### 3.2 Approval Permissions ✅
**Table:** `approval_permissions`  
**Status:** Working correctly  
**Controls:** Approval limits and permissions  
**Action:** DO NOT MODIFY

### 3.3 Customer Access Codes ✅
**System:** Customer authentication via access codes  
**Status:** Working correctly  
**Action:** DO NOT MODIFY

---

## 4. What Needs to Be Fixed

### 4.1 Incomplete Role Permissions Data
**Problem:** Only 12 records in `role_permissions` table  
**Need:** 86+ records (43 functions × 2 base roles minimum)  
**Solution:** Run permission regeneration script

### 4.2 No Permission Utility Functions
**Problem:** No centralized permission checking code  
**Need:** 
- `hasPermission(functionCode, action)` function
- `FUNCTION_CODES` constants
- Backward compatibility with role_type checks

### 4.3 Hardcoded Role Checks Throughout UI
**Problem:** 44+ locations with direct `role_type === 'Master Admin'` checks  
**Need:** Replace with permission utility calls  
**Locations:**
- Desktop interface: 29 files
- Mobile interface: 15 files

### 4.4 Missing User Permissions Loading
**Problem:** User permissions not loaded on login  
**Need:** Update `userAuth.ts` to fetch and store user permissions

---

## 5. Implementation Plan Overview

### Phase 1: Database Setup
1. Add missing 37 functions to `app_functions`
2. Regenerate all role permissions (delete old, create fresh 86+ records)
3. Verify database state

### Phase 2: Create Permission Infrastructure
1. Create `FUNCTION_CODES` constants file
2. Create `permissions.ts` utility with `hasPermission()` function
3. Add backward compatibility (fallback to role_type checks)

### Phase 3: Update Authentication
1. Modify `userAuth.ts` to fetch user permissions on login
2. Store permissions in user object
3. Update user type definitions

### Phase 4: Replace Hardcoded Checks - Desktop Interface
1. Update 8 desktop interface files with permission checks
2. Test each file after update
3. Verify Master Admin still has full access

### Phase 5: Replace Hardcoded Checks - Mobile Interface
1. Update 4 mobile interface routes
2. Test mobile access
3. Verify backward compatibility

### Phase 6: Testing & Validation
1. Test Master Admin access (full permissions)
2. Test Admin access (limited permissions)
3. Test Position-based users (custom permissions)
4. Verify no regressions

### Phase 7: Documentation & Cleanup
1. Update documentation
2. Create guide for adding new functions
3. Remove TODO comments

---

## 6. Restrictions to Preserve

### ✅ Keep These (Business Logic, Not Permissions):

1. **Task role_type checks** - Workflow logic
   - `inventory_manager`, `purchase_manager`, `shelf_stocker`, etc.
   
2. **Interface permissions table** - Already working
   - Desktop/Mobile/Customer app access
   
3. **Approval permissions table** - Already working
   - Approval limits and workflow

4. **Customer authentication** - Separate system
   - Access code login

5. **Master Admin protection** - System safety
   - Cannot delete own Master Admin account
   - Cannot deactivate last active Master Admin
   - Maximum Master Admin limit enforced

---

## 7. Files to Create

### New Files Needed:
1. `frontend/src/lib/constants/functionCodes.ts` - Function code constants
2. `frontend/src/lib/utils/permissions.ts` - Permission utility functions
3. `scripts/regenerate-role-permissions.js` - Clean permission regeneration

---

## 8. Files to Modify

### Database Scripts:
1. `scripts/add-missing-functions.js` - Already exists, need to run

### Authentication:
1. `frontend/src/lib/utils/userAuth.ts` - Add permission loading
2. `frontend/src/lib/types/auth.ts` - Update User type

### Desktop Interface (8 files):
1. `frontend/src/lib/components/desktop-interface/settings/UserManagement.svelte`
2. `frontend/src/lib/components/desktop-interface/settings/user/CreateUserRoles.svelte`
3. `frontend/src/lib/components/desktop-interface/settings/user/AssignRoles.svelte`
4. `frontend/src/lib/components/desktop-interface/settings/user/EditUser.svelte`
5. `frontend/src/lib/components/desktop-interface/settings/ApprovalPermissionsManager.svelte`
6. `frontend/src/lib/components/desktop-interface/master/CommunicationCenter.svelte`
7. `frontend/src/lib/components/desktop-interface/master/communication/NotificationCenter.svelte`
8. `frontend/src/lib/components/desktop-interface/master/communication/CreateNotification.svelte`

### Mobile Interface (4 files):
1. `frontend/src/routes/mobile-interface/+page.svelte`
2. `frontend/src/routes/mobile-interface/reports/+page.svelte`
3. `frontend/src/routes/mobile-interface/notifications/create/+page.svelte`
4. `frontend/src/lib/components/mobile-interface/notifications/NotificationCenter.svelte`

---

## 9. Risk Assessment

### Low Risk ✅
- Creating new utility functions
- Adding permission constants
- Running database scripts (with backups)

### Medium Risk ⚠️
- Modifying authentication flow
- Updating user type definitions
- Replacing hardcoded checks (may break features if done incorrectly)

### High Risk 🚨
- None if backward compatibility maintained
- Master Admin protection must remain intact

### Mitigation Strategy:
1. **Backward compatibility** - Fallback to role_type if permissions missing
2. **Incremental updates** - Replace one file at a time, test immediately
3. **No deployment** until all testing complete
4. **Keep task role_type checks** - Don't touch workflow logic

---

## 10. Success Criteria

### Must Have Before Completion:
- [ ] 43 functions in `app_functions` table
- [ ] 86+ permissions in `role_permissions` table
- [ ] Permission utilities created and working
- [ ] All 12 files updated with permission checks
- [ ] No hardcoded `Master Admin`/`Admin` checks remain (except task role_type)
- [ ] Master Admin has full access to everything
- [ ] Admin has appropriate restricted access
- [ ] Position-based users can have custom permissions
- [ ] Backward compatibility works (old users still work)
- [ ] No console errors
- [ ] All existing features still work
- [ ] Mobile interface works correctly
- [ ] Desktop interface works correctly

---

## 11. Related Documents

- `PERMISSION_SYSTEM_IMPLEMENTATION_CHECKLIST.md` - Step-by-step implementation guide
- `ADD_NEW_FUNCTION_GUIDE.md` - How to add new functions in the future
- `DATABASE_FUNCTIONS.md` - All database functions documentation
- `DATABASE_SCHEMA.md` - Complete schema reference

---

## 12. Questions Answered

### Q: Are there hardcoded restrictions?
**A:** Yes, 44+ locations with direct role_type comparisons throughout desktop and mobile interfaces

### Q: Are there other restrictions?
**A:** Yes, several systems:
1. Task role_type checks (business logic - keep these)
2. Interface permissions (working - keep as is)
3. Approval permissions (working - keep as is)
4. Master Admin protections (keep for system safety)

### Q: What needs to be changed?
**A:** 
1. Complete the role_permissions data (86+ records needed)
2. Create permission utility functions
3. Replace 44+ hardcoded role checks with permission calls
4. Update authentication to load user permissions

---

## Next Steps

1. Review this analysis with team
2. Proceed with `PERMISSION_SYSTEM_IMPLEMENTATION_CHECKLIST.md`
3. Start with Phase 1: Database Setup
4. Test incrementally after each phase
5. Deploy only after all phases complete and tested

---

**Document Version:** 1.0  
**Last Updated:** December 1, 2025  
**Status:** Ready for Implementation
