# Permission System Implementation Checklist

## Implementation Strategy

**Approach:** Clean regeneration with backward-compatible transition  
**Status:** 🟡 IN PROGRESS  
**Started:** 2025-11-30  
**Completed:** _Pending_

---

## ✅ Prerequisites Confirmed

- [x] Won't deploy/push to git until all work is complete
- [x] Give all users full permissions initially (manage via UI later)
- [x] Clean regeneration: Delete existing 12 permissions, create fresh for all 43 functions
- [x] Backward compatible: hasPermission() falls back to roleType check if permission missing
- [x] Keep task role_type checks (inventory_manager, etc.) - they're business logic
- [x] Keep interface_permissions checks - already working correctly

---

## 📋 Phase 1: Database Setup

### Step 1.1: Add Missing Functions to Database
**File:** `scripts/add-missing-functions.js` (already created)  
**Action:** Run script to populate app_functions table

- [ ] 1.1.1 - Review script to ensure it adds all 37 missing functions
- [ ] 1.1.2 - Run: `node scripts/add-missing-functions.js`
- [ ] 1.1.3 - Verify output shows 37 functions added successfully
- [ ] 1.1.4 - Check database: `app_functions` table should have 43 total records
- [ ] 1.1.5 - Verify no duplicate function_code errors

**Expected Result:** 43 functions in app_functions (6 existing + 37 new)

---

### Step 1.2: Regenerate All Role Permissions (Clean)
**File:** New script to create  
**Action:** Delete old permissions, create fresh for all 43 functions

- [ ] 1.2.1 - Create `scripts/regenerate-role-permissions.js`
- [ ] 1.2.2 - Script deletes ALL existing role_permissions entries
- [ ] 1.2.3 - Script creates permissions for Master Admin (full access to all 43)
- [ ] 1.2.4 - Script creates permissions for Admin (view/add/edit to all 43, no delete)
- [ ] 1.2.5 - Run: `node scripts/regenerate-role-permissions.js`
- [ ] 1.2.6 - Verify output shows permissions created successfully
- [ ] 1.2.7 - Check database: `role_permissions` should have 86 records (43×2 roles)

**Expected Result:** Clean permission set for Master Admin + Admin covering all 43 functions

---

### Step 1.3: Verify Database State
**Action:** Manual verification in Supabase

- [ ] 1.3.1 - Query: `SELECT COUNT(*) FROM app_functions` → Should return 43
- [ ] 1.3.2 - Query: `SELECT COUNT(*) FROM role_permissions` → Should return 86
- [ ] 1.3.3 - Query: `SELECT * FROM role_permissions WHERE role_id IN (SELECT id FROM user_roles WHERE role_code IN ('MASTER_ADMIN', 'ADMIN'))` → Verify structure
- [ ] 1.3.4 - Spot check: Master Admin has can_delete=true, Admin has can_delete=false

**Expected Result:** Database ready with complete permission structure

---

## 📋 Phase 2: Create Permission Utilities

### Step 2.1: Create Function Code Constants
**File:** `frontend/src/lib/constants/functionCodes.ts` (new file)

- [ ] 2.1.1 - Create directory if not exists: `frontend/src/lib/constants/`
- [ ] 2.1.2 - Create `functionCodes.ts` with all 43 function codes
- [ ] 2.1.3 - Use UPPERCASE_SNAKE_CASE naming (e.g., DASHBOARD, USER_MGMT)
- [ ] 2.1.4 - Export as const object with TypeScript type
- [ ] 2.1.5 - Verify no syntax errors: `npm run lint` (if fails, fix)
- [ ] 2.1.6 - Test import: Add `import { FUNCTION_CODES } from '$lib/constants/functionCodes'` to a test file

**Expected Result:** Centralized function code constants available for import

---

### Step 2.2: Create Permission Utility Functions
**File:** `frontend/src/lib/utils/permissions.ts` (new file)

- [ ] 2.2.1 - Create `permissions.ts` with hasPermission() function
- [ ] 2.2.2 - Implement backward-compatible logic:
  - Check user.permissions first
  - If permission exists, use it
  - If permission missing, fallback to roleType === 'Master Admin' || 'Admin'
- [ ] 2.2.3 - Add getPermissions() helper function
- [ ] 2.2.4 - Add canAccessFunction() convenience function
- [ ] 2.2.5 - Import currentUser store from auth
- [ ] 2.2.6 - Add proper TypeScript types for all functions
- [ ] 2.2.7 - Verify no syntax errors: `npm run lint`
- [ ] 2.2.8 - Test in browser console: Import and call hasPermission()

**Expected Result:** Working permission utility with backward compatibility

---

### Step 2.3: Test Permission Utilities
**Action:** Manual testing in browser DevTools

- [ ] 2.3.1 - Start dev server: Ensure task "🎨 Dev Frontend (npm)" is running
- [ ] 2.3.2 - Open browser to http://localhost:5173
- [ ] 2.3.3 - Login as Master Admin user
- [ ] 2.3.4 - Open DevTools Console
- [ ] 2.3.5 - Test: `import { hasPermission } from '$lib/utils/permissions'; hasPermission('DASHBOARD', 'view')` → Should return true
- [ ] 2.3.6 - Test: `hasPermission('NONEXISTENT', 'view')` → Should fallback and return true for Master Admin
- [ ] 2.3.7 - Logout and login as regular user → Test should return appropriate values

**Expected Result:** Permission utility works correctly with fallback

---

## 📋 Phase 3: Update Sidebar Navigation

### Step 3.1: Update Sidebar.svelte - Reports Section
**File:** `frontend/src/lib/components/Sidebar.svelte`  
**Lines:** 981

- [ ] 3.1.1 - Import hasPermission and FUNCTION_CODES at top of script
- [ ] 3.1.2 - Find line 981: `{#if $currentUser?.roleType === 'Master Admin' || $currentUser?.roleType === 'Admin'}`
- [ ] 3.1.3 - Replace with: `{#if hasPermission(FUNCTION_CODES.SALES_REPORTS, 'view')}`
- [ ] 3.1.4 - Save file
- [ ] 3.1.5 - Check for syntax errors in terminal
- [ ] 3.1.6 - Test in browser: Reports menu item should still appear for Master Admin/Admin

**Expected Result:** Reports menu controlled by permission system

---

### Step 3.2: Update Sidebar.svelte - Expenses Section  
**File:** `frontend/src/lib/components/Sidebar.svelte`  
**Lines:** 1079

- [ ] 3.2.1 - Find line 1079: Admin/Master Admin check
- [ ] 3.2.2 - Replace with: `{#if hasPermission(FUNCTION_CODES.EXPENSE_MGMT, 'view')}`
- [ ] 3.2.3 - Save and verify no errors
- [ ] 3.2.4 - Test in browser: Expenses menu item visible

**Expected Result:** Expenses menu controlled by permission system

---

### Step 3.3: Update Sidebar.svelte - Receiving Section
**File:** `frontend/src/lib/components/Sidebar.svelte`  
**Lines:** 1141

- [ ] 3.3.1 - Find line 1141: Admin/Master Admin check  
- [ ] 3.3.2 - Replace with: `{#if hasPermission(FUNCTION_CODES.RECEIVING_MGMT, 'view')}`
- [ ] 3.3.3 - Save and verify no errors
- [ ] 3.3.4 - Test in browser: Receiving menu item visible

**Expected Result:** Receiving menu controlled by permission system

---

### Step 3.4: Update Sidebar.svelte - Notifications Section
**File:** `frontend/src/lib/components/Sidebar.svelte`  
**Lines:** 1197

- [ ] 3.4.1 - Find line 1197: Admin/Master Admin check
- [ ] 3.4.2 - Replace with: `{#if hasPermission(FUNCTION_CODES.NOTIFICATION_CENTER, 'view')}`
- [ ] 3.4.3 - Save and verify no errors
- [ ] 3.4.4 - Test in browser: Notifications menu item visible

**Expected Result:** Notifications menu controlled by permission system

---

### Step 3.5: Update Sidebar.svelte - User Management Section
**File:** `frontend/src/lib/components/Sidebar.svelte`  
**Lines:** 1229

- [ ] 3.5.1 - Find line 1229: Master Admin only check
- [ ] 3.5.2 - Replace with: `{#if hasPermission(FUNCTION_CODES.USER_MGMT, 'view')}`
- [ ] 3.5.3 - Save and verify no errors
- [ ] 3.5.4 - Test in browser: User Management visible for Master Admin, hidden for others

**Expected Result:** User Management menu controlled by permission system

---

### Step 3.6: Test Complete Sidebar
**Action:** Full sidebar verification

- [ ] 3.6.1 - Login as Master Admin → All menu items visible
- [ ] 3.6.2 - Login as Admin → Most items visible (User Management should show based on permissions)
- [ ] 3.6.3 - Login as regular Position-based user → Menu reflects permissions
- [ ] 3.6.4 - Check browser console for errors → Should be none
- [ ] 3.6.5 - Test clicking each menu item → Windows open correctly

**Expected Result:** Sidebar fully functional with permission checks

---

## 📋 Phase 4: Update Mobile Routes

### Step 4.1: Update Mobile Reports Page
**File:** `frontend/src/routes/mobile/reports/+page.svelte`  
**Lines:** 27

- [ ] 4.1.1 - Import hasPermission and FUNCTION_CODES
- [ ] 4.1.2 - Find line 27: `if (userRole !== 'Master Admin' && userRole !== 'Admin')`
- [ ] 4.1.3 - Replace with: `if (!hasPermission(FUNCTION_CODES.SALES_REPORTS, 'view'))`
- [ ] 4.1.4 - Save and verify no errors
- [ ] 4.1.5 - Test mobile interface: Access reports page as Master Admin → Works
- [ ] 4.1.6 - Test as regular user without permission → Access denied message

**Expected Result:** Reports page access controlled by permissions

---

### Step 4.2: Update Mobile Notifications Create Page
**File:** `frontend/src/routes/mobile/notifications/create/+page.svelte`  
**Lines:** 12

- [ ] 4.2.1 - Import hasPermission and FUNCTION_CODES
- [ ] 4.2.2 - Find line 12: `$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin'`
- [ ] 4.2.3 - Replace with: `$: canCreateNotification = hasPermission(FUNCTION_CODES.PUSH_NOTIFICATIONS, 'add')`
- [ ] 4.2.4 - Update template to use `canCreateNotification` instead of `isAdminOrMaster`
- [ ] 4.2.5 - Save and verify no errors
- [ ] 4.2.6 - Test: Create notification button visible based on permissions

**Expected Result:** Notification creation controlled by permissions

---

### Step 4.3: Update Mobile Dashboard Page
**File:** `frontend/src/routes/mobile/+page.svelte`  
**Lines:** 36

- [ ] 4.3.1 - Import hasPermission and FUNCTION_CODES
- [ ] 4.3.2 - Find line 36: `$: isAdminOrMaster = userRole === 'Admin' || userRole === 'Master Admin'`
- [ ] 4.3.3 - Replace with: `$: canAccessDashboard = hasPermission(FUNCTION_CODES.DASHBOARD, 'view')`
- [ ] 4.3.4 - Update template to use `canAccessDashboard` instead of `isAdminOrMaster`
- [ ] 4.3.5 - Save and verify no errors
- [ ] 4.3.6 - Test: Dashboard features visible based on permissions

**Expected Result:** Dashboard access controlled by permissions

---

### Step 4.4: Update Mobile Layout
**File:** `frontend/src/routes/mobile/+layout.svelte`  
**Lines:** 551

- [ ] 4.4.1 - Import hasPermission and FUNCTION_CODES
- [ ] 4.4.2 - Find line 551: Admin/Master Admin check
- [ ] 4.4.3 - Replace with appropriate permission check (determine which function this controls)
- [ ] 4.4.4 - Save and verify no errors
- [ ] 4.4.5 - Test: Mobile layout features controlled by permissions

**Expected Result:** Mobile layout respects permissions

---

## 📋 Phase 5: Update Admin Components

### Step 5.1: Update UserManagement Component
**File:** `frontend/src/lib/components/admin/UserManagement.svelte`  
**Lines:** 123, 130, 271, 441

- [ ] 5.1.1 - Import hasPermission and FUNCTION_CODES
- [ ] 5.1.2 - Line 123: Replace Master Admin check with `hasPermission(FUNCTION_CODES.USER_MGMT, 'edit')`
- [ ] 5.1.3 - Line 130: Replace Admin check with `hasPermission(FUNCTION_CODES.USER_MGMT, 'view')`
- [ ] 5.1.4 - Line 271: Update condition to use permission check
- [ ] 5.1.5 - Line 441: Update disabled condition to use permission check
- [ ] 5.1.6 - Save and verify no errors
- [ ] 5.1.7 - Test: User management features work correctly
- [ ] 5.1.8 - Test: Access denied for users without permission

**Expected Result:** User management controlled by permissions

---

### Step 5.2: Update NotificationCenter Component
**File:** `frontend/src/lib/components/admin/communication/NotificationCenter.svelte`  
**Lines:** 19, 1001

- [ ] 5.2.1 - Import hasPermission and FUNCTION_CODES
- [ ] 5.2.2 - Line 19: Replace `$: isAdminOrMaster = ...` with `$: canSendNotifications = hasPermission(FUNCTION_CODES.PUSH_NOTIFICATIONS, 'add')`
- [ ] 5.2.3 - Line 1001: Update condition to use `canSendNotifications`
- [ ] 5.2.4 - Save and verify no errors
- [ ] 5.2.5 - Test: Send notification button visible based on permissions

**Expected Result:** Notification center controlled by permissions

---

### Step 5.3: Update ApprovalPermissionsManager Component
**File:** `frontend/src/lib/components/admin/ApprovalPermissionsManager.svelte`  
**Lines:** 19, 225

- [ ] 5.3.1 - Import hasPermission and FUNCTION_CODES
- [ ] 5.3.2 - Determine appropriate function code (may need to add APPROVAL_MGMT to database)
- [ ] 5.3.3 - Line 19: Replace Master Admin check with permission check
- [ ] 5.3.4 - Line 225: Update access denied condition
- [ ] 5.3.5 - Save and verify no errors
- [ ] 5.3.6 - Test: Approval management accessible based on permissions

**Expected Result:** Approval management controlled by permissions

---

## 📋 Phase 6: Full System Testing

### Step 6.1: Master Admin Testing
**User:** Login as Master Admin

- [ ] 6.1.1 - Desktop sidebar shows all menu items
- [ ] 6.1.2 - Can access all features (HR, Tasks, Receiving, Reports, etc.)
- [ ] 6.1.3 - All action buttons visible (Add, Edit, Delete, Export)
- [ ] 6.1.4 - Mobile interface shows all features
- [ ] 6.1.5 - No console errors
- [ ] 6.1.6 - Can create/edit/delete records in all modules

**Expected Result:** Master Admin has full system access

---

### Step 6.2: Admin Testing
**User:** Login as Admin

- [ ] 6.2.1 - Desktop sidebar shows most menu items
- [ ] 6.2.2 - Can access admin features
- [ ] 6.2.3 - Action buttons respect permissions (may not have Delete button)
- [ ] 6.2.4 - Mobile interface works correctly
- [ ] 6.2.5 - No console errors
- [ ] 6.2.6 - Can view/add/edit but not delete (based on permissions)

**Expected Result:** Admin has appropriate limited access

---

### Step 6.3: Regular User Testing
**User:** Login as Position-based user

- [ ] 6.3.1 - Sidebar shows only permitted functions
- [ ] 6.3.2 - Cannot access restricted features
- [ ] 6.3.3 - Direct URL navigation to unauthorized pages shows access denied
- [ ] 6.3.4 - Mobile interface respects permissions
- [ ] 6.3.5 - No console errors
- [ ] 6.3.6 - Can only perform permitted actions

**Expected Result:** Regular user access properly restricted

---

### Step 6.4: Cross-Browser Testing

- [ ] 6.4.1 - Test in Chrome: All features work
- [ ] 6.4.2 - Test in Firefox: All features work
- [ ] 6.4.3 - Test in Edge: All features work
- [ ] 6.4.4 - Test in Safari (if available): All features work
- [ ] 6.4.5 - Test mobile Chrome: All features work
- [ ] 6.4.6 - Test mobile Safari (if available): All features work

**Expected Result:** Consistent behavior across browsers

---

### Step 6.5: Permission Fallback Testing

- [ ] 6.5.1 - Temporarily remove permission from database for a test user
- [ ] 6.5.2 - Login as that user
- [ ] 6.5.3 - Verify backward compatibility: Fallback to roleType check works
- [ ] 6.5.4 - Restore permission in database
- [ ] 6.5.5 - Verify permission from database takes precedence

**Expected Result:** Fallback mechanism works correctly

---

## 📋 Phase 7: Create Admin UI for Permission Management (Future)

**Note:** This phase is NOT part of current implementation. Marked for future development.

- [ ] 7.1 - Design UserPermissionManager UI component
- [ ] 7.2 - Create API endpoints for permission management
- [ ] 7.3 - Implement permission assignment interface
- [ ] 7.4 - Add to admin menu in Sidebar
- [ ] 7.5 - Test permission changes take effect on next login
- [ ] 7.6 - Add bulk permission management
- [ ] 7.7 - Add permission templates

**Status:** 🔵 PLANNED (Not started)

---

## 📋 Phase 8: Documentation & Cleanup

### Step 8.1: Update Documentation

- [ ] 8.1.1 - Update README.md with permission system overview
- [ ] 8.1.2 - Document how to add new functions (reference ADD_NEW_FUNCTION_GUIDE.md)
- [ ] 8.1.3 - Update developer onboarding docs
- [ ] 8.1.4 - Create user guide for understanding access levels

**Expected Result:** Complete documentation for permission system

---

### Step 8.2: Code Cleanup

- [ ] 8.2.1 - Remove commented-out old code if any
- [ ] 8.2.2 - Ensure all imports are used (no unused imports)
- [ ] 8.2.3 - Run linter: `npm run lint` → Fix any issues
- [ ] 8.2.4 - Format code: `npm run format` (if available)
- [ ] 8.2.5 - Review console logs - remove debug logs
- [ ] 8.2.6 - Check for TODO comments - address or document

**Expected Result:** Clean, production-ready code

---

### Step 8.3: Final Verification

- [ ] 8.3.1 - Full system test with all user types
- [ ] 8.3.2 - No console errors in any scenario
- [ ] 8.3.3 - All features working as expected
- [ ] 8.3.4 - Performance is acceptable (no noticeable slowdown)
- [ ] 8.3.5 - Database queries optimized (check slow query log if available)

**Expected Result:** System fully functional and performant

---

## 📋 Phase 9: Prepare for Deployment

### Step 9.1: Pre-Deployment Checklist

- [ ] 9.1.1 - Run full test suite: `npm test` (if tests exist)
- [ ] 9.1.2 - Build production bundle: `npm run build`
- [ ] 9.1.3 - Verify build succeeds with no errors
- [ ] 9.1.4 - Test production build locally
- [ ] 9.1.5 - Check bundle size - ensure not too large
- [ ] 9.1.6 - Review git diff - verify all changes are intentional

**Expected Result:** Ready for deployment

---

### Step 9.2: Database Backup

- [ ] 9.2.1 - Backup app_functions table
- [ ] 9.2.2 - Backup role_permissions table
- [ ] 9.2.3 - Backup user_roles table
- [ ] 9.2.4 - Store backups in safe location
- [ ] 9.2.5 - Document restore procedure if needed

**Expected Result:** Can rollback database if needed

---

### Step 9.3: Git Commit & Push

- [ ] 9.3.1 - Review all changed files: `git status`
- [ ] 9.3.2 - Stage changes: `git add -A`
- [ ] 9.3.3 - Commit with descriptive message: `git commit -m "feat: implement complete permission system with 43 functions"`
- [ ] 9.3.4 - Push to remote: `git push origin master`
- [ ] 9.3.5 - Verify push succeeded
- [ ] 9.3.6 - Create git tag: `git tag -a v2.1.0 -m "Permission system implementation"`
- [ ] 9.3.7 - Push tag: `git push origin v2.1.0`

**Expected Result:** Changes committed and pushed to repository

---

## 🎯 Success Criteria

All must be true before marking implementation complete:

- [x] Database has 43 functions in app_functions
- [ ] Database has 86 role_permissions (Master Admin + Admin × 43 functions)
- [ ] Permission utilities created and working
- [ ] All 8 files updated with permission checks
- [ ] No hardcoded Master Admin/Admin checks remain (except task role_type)
- [ ] All tests pass
- [ ] No console errors
- [ ] Master Admin has full access
- [ ] Admin has appropriate access
- [ ] Regular users properly restricted
- [ ] Backward compatibility works
- [ ] Documentation updated
- [ ] Code committed to git

---

## 📊 Progress Tracking

**Phases Completed:** 0 / 9  
**Steps Completed:** 0 / 120+  
**Overall Progress:** 0%

### Phase Status:
- 🔴 Not Started: Phase 1-9
- 🟡 In Progress: None
- 🟢 Completed: None

---

## 🚨 Blockers & Issues

**Current Blockers:** None

**Issues Log:**
- _No issues yet_

---

## 📝 Notes & Decisions

**Decision Log:**
1. ✅ Give all users full permissions initially (manage via UI later)
2. ✅ Clean regeneration: Delete existing 12 permissions, recreate all
3. ✅ Backward compatible: Fallback to roleType if permission missing
4. ✅ Keep task role_type checks (business logic, not permissions)
5. ✅ Keep interface_permissions checks (already working)

**Important Reminders:**
- DO NOT touch task role_type checks (inventory_manager, purchase_manager, etc.)
- DO NOT touch interface_permissions checks
- ALWAYS test after each step
- USE backward compatibility during transition
- UPDATE this checklist as you progress

---

## 🔗 Related Documents

- `USER_FUNCTION_CONTROL_PLAN.md` - Overall system design
- `ADD_NEW_FUNCTION_GUIDE.md` - How to add functions in future
- `HARDCODED_PERMISSIONS_ANALYSIS.md` - Analysis of current hardcoded checks
- `scripts/add-missing-functions.js` - Database population script
- `scripts/regenerate-role-permissions.js` - Permission regeneration script (to be created)

---

**Last Updated:** 2025-11-30  
**Implementation Status:** 🟡 Ready to Begin  
**Target Completion:** TBD