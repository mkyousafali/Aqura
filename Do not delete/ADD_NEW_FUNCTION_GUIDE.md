# Guide: Adding New Functions to Permission System

## Overview

This guide explains how to add a new feature/function to Aqura's permission control system. Follow these steps whenever you create a new module, component, or feature that needs access control.

---

## Step-by-Step Process

### Step 1: Add Function to Database

Add the new function to `app_functions` table.

**Example: Adding "Biometric Management" feature**

```javascript
// Run this script or execute in Supabase SQL editor
const { data, error } = await supabase
  .from('app_functions')
  .insert({
    function_name: 'Biometric Management',
    function_code: 'BIOMETRIC_MGMT',  // Always UPPERCASE_SNAKE_CASE
    description: 'Manage biometric device connections and sync',
    category: 'Operations',  // Categories: System, Administration, Master Data, Operations, Finance, Customer, Product, Reports
    is_active: true
  });
```

**SQL Alternative:**
```sql
INSERT INTO app_functions (
  function_name, 
  function_code, 
  description, 
  category, 
  is_active
) VALUES (
  'Biometric Management',
  'BIOMETRIC_MGMT',
  'Manage biometric device connections and sync',
  'Operations',
  true
);
```

**Function Code Naming Convention:**
- Use UPPERCASE with underscores
- Be descriptive but concise
- Examples: `HR_MASTER`, `RECEIVING_MGMT`, `EXPENSE_MGMT`, `COUPON_REDEMPTION`

**Categories:**
- **System** - Core system features (Dashboard, Settings, Audit)
- **Administration** - User/role management, system configuration
- **Master Data** - HR, Branches, base data management
- **Operations** - Receiving, Vendors, Inventory, daily operations
- **Finance** - Expenses, Payments, Budget, financial operations
- **Customer** - Customer management, registration, recovery
- **Product** - Products, categories, pricing, catalog management
- **Reports** - All reporting functions
- **Offers & Promotions** - Offers, coupons, discounts

---

### Step 2: Add Default Role Permissions

Assign default permissions to roles (at minimum: Master Admin and Admin).

```javascript
// Get the function ID first
const { data: func } = await supabase
  .from('app_functions')
  .select('id')
  .eq('function_code', 'BIOMETRIC_MGMT')
  .single();

// Get role IDs
const { data: masterAdmin } = await supabase
  .from('user_roles')
  .select('id')
  .eq('role_code', 'MASTER_ADMIN')
  .single();

const { data: admin } = await supabase
  .from('user_roles')
  .select('id')
  .eq('role_code', 'ADMIN')
  .single();

// Assign permissions
await supabase.from('role_permissions').insert([
  {
    role_id: masterAdmin.id,
    function_id: func.id,
    can_view: true,
    can_add: true,
    can_edit: true,
    can_delete: true,
    can_export: true
  },
  {
    role_id: admin.id,
    function_id: func.id,
    can_view: true,
    can_add: true,
    can_edit: true,
    can_delete: false,  // Admins typically can't delete
    can_export: true
  }
]);
```

**SQL Alternative:**
```sql
-- Insert permissions for Master Admin (full access)
INSERT INTO role_permissions (role_id, function_id, can_view, can_add, can_edit, can_delete, can_export)
SELECT 
  ur.id,
  af.id,
  true, true, true, true, true
FROM user_roles ur
CROSS JOIN app_functions af
WHERE ur.role_code = 'MASTER_ADMIN'
  AND af.function_code = 'BIOMETRIC_MGMT';

-- Insert permissions for Admin (limited access)
INSERT INTO role_permissions (role_id, function_id, can_view, can_add, can_edit, can_delete, can_export)
SELECT 
  ur.id,
  af.id,
  true, true, true, false, true
FROM user_roles ur
CROSS JOIN app_functions af
WHERE ur.role_code = 'ADMIN'
  AND af.function_code = 'BIOMETRIC_MGMT';
```

---

### Step 3: Add Function Code Constant

Add the function code to a centralized constants file.

**Create/Update: `frontend/src/lib/constants/functionCodes.ts`**

```typescript
// Function codes for permission checking
export const FUNCTION_CODES = {
  // System
  DASHBOARD: 'DASHBOARD',
  SETTINGS: 'SETTINGS',
  
  // Administration
  USER_MGMT: 'USER_MGMT',
  
  // Master Data
  HR_MASTER: 'HR_MASTER',
  BRANCH_MASTER: 'BRANCH_MASTER',
  TASK_MASTER: 'TASK_MASTER',
  
  // Operations
  RECEIVING_MGMT: 'RECEIVING_MGMT',
  VENDOR_MGMT: 'VENDOR_MGMT',
  BIOMETRIC_MGMT: 'BIOMETRIC_MGMT',  // ← Add new function here
  
  // Finance
  EXPENSE_MGMT: 'EXPENSE_MGMT',
  REQUISITION_MGMT: 'REQUISITION_MGMT',
  
  // Add more as needed...
} as const;

export type FunctionCode = typeof FUNCTION_CODES[keyof typeof FUNCTION_CODES];
```

---

### Step 4: Add to Sidebar Menu (If applicable)

If the function should appear in the sidebar navigation, add permission check.

**Update: `frontend/src/lib/components/Sidebar.svelte`**

```svelte
<script lang="ts">
  import { hasPermission } from '$lib/utils/permissions';
  import { FUNCTION_CODES } from '$lib/constants/functionCodes';
</script>

<!-- Existing menu items -->

<!-- Add new menu item with permission check -->
{#if hasPermission(FUNCTION_CODES.BIOMETRIC_MGMT, 'view')}
  <button
    on:click={() => openWindow('BiometricManagement', {})}
    class="menu-item"
  >
    <Icon name="fingerprint" />
    <span>{$t('sidebar.biometricManagement')}</span>
  </button>
{/if}
```

**Add Translation:**

`frontend/src/lib/i18n/locales/en.ts`:
```typescript
sidebar: {
  // ... existing translations
  biometricManagement: "Biometric Management",
}
```

`frontend/src/lib/i18n/locales/ar.ts`:
```typescript
sidebar: {
  // ... existing translations
  biometricManagement: "إدارة البصمات",
}
```

---

### Step 5: Add Permission Checks to Component

Add permission checks to your new component for action buttons.

**Create: `frontend/src/lib/components/admin/BiometricManagement.svelte`**

```svelte
<script lang="ts">
  import { hasPermission } from '$lib/utils/permissions';
  import { FUNCTION_CODES } from '$lib/constants/functionCodes';
  
  const canView = hasPermission(FUNCTION_CODES.BIOMETRIC_MGMT, 'view');
  const canAdd = hasPermission(FUNCTION_CODES.BIOMETRIC_MGMT, 'add');
  const canEdit = hasPermission(FUNCTION_CODES.BIOMETRIC_MGMT, 'edit');
  const canDelete = hasPermission(FUNCTION_CODES.BIOMETRIC_MGMT, 'delete');
  const canExport = hasPermission(FUNCTION_CODES.BIOMETRIC_MGMT, 'export');
  
  // Redirect if no view permission
  onMount(() => {
    if (!canView) {
      notifications.add({
        message: 'Access Denied',
        type: 'error'
      });
      closeWindow();
    }
  });
</script>

<!-- Component UI -->
<div class="biometric-management">
  <!-- Header with conditional buttons -->
  <div class="header">
    <h2>Biometric Management</h2>
    
    <div class="actions">
      {#if canAdd}
        <button on:click={addDevice}>Add Device</button>
      {/if}
      
      {#if canExport}
        <button on:click={exportData}>Export</button>
      {/if}
    </div>
  </div>
  
  <!-- Data table -->
  <table>
    <!-- ... table content ... -->
    <tr>
      <td>{device.name}</td>
      <td>
        {#if canEdit}
          <button on:click={() => editDevice(device)}>Edit</button>
        {/if}
        
        {#if canDelete}
          <button on:click={() => deleteDevice(device)}>Delete</button>
        {/if}
      </td>
    </tr>
  </table>
</div>
```

---

### Step 6: Add Route Guard (Optional)

If the function has a dedicated route, add permission check.

**Create: `frontend/src/routes/biometric/+page.svelte`**

```svelte
<script lang="ts">
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { hasPermission } from '$lib/utils/permissions';
  import { FUNCTION_CODES } from '$lib/constants/functionCodes';
  import { notifications } from '$lib/stores/notifications';
  
  onMount(() => {
    if (!hasPermission(FUNCTION_CODES.BIOMETRIC_MGMT, 'view')) {
      notifications.add({
        message: 'You do not have permission to access this page',
        type: 'error'
      });
      goto('/'); // Redirect to home
    }
  });
</script>

<BiometricManagement />
```

---

### Step 7: Update Permission Manager UI (If needed)

The admin permission management UI should automatically pick up new functions from the database. No code changes needed if using dynamic function loading.

**Verify in Admin UI:**
1. Go to User Management → Permissions
2. New function should appear in the appropriate category
3. Admin can assign permissions to users

---

## Complete Example: Adding "Sales Reports" Function

### 1. Database Insert
```sql
INSERT INTO app_functions (function_name, function_code, description, category, is_active)
VALUES ('Sales Reports', 'SALES_REPORTS', 'Generate and view sales analytics reports', 'Reports', true);
```

### 2. Role Permissions
```sql
-- Master Admin: Full access
INSERT INTO role_permissions (role_id, function_id, can_view, can_add, can_edit, can_delete, can_export)
SELECT ur.id, af.id, true, true, true, true, true
FROM user_roles ur CROSS JOIN app_functions af
WHERE ur.role_code = 'MASTER_ADMIN' AND af.function_code = 'SALES_REPORTS';

-- Admin: View and export only
INSERT INTO role_permissions (role_id, function_id, can_view, can_add, can_edit, can_delete, can_export)
SELECT ur.id, af.id, true, false, false, false, true
FROM user_roles ur CROSS JOIN app_functions af
WHERE ur.role_code = 'ADMIN' AND af.function_code = 'SALES_REPORTS';
```

### 3. Function Code Constant
```typescript
// frontend/src/lib/constants/functionCodes.ts
export const FUNCTION_CODES = {
  // ... existing codes ...
  SALES_REPORTS: 'SALES_REPORTS',
};
```

### 4. Sidebar Menu
```svelte
{#if hasPermission(FUNCTION_CODES.SALES_REPORTS, 'view')}
  <button on:click={() => openWindow('SalesReports', {})}>
    <Icon name="chart-bar" />
    <span>{$t('sidebar.salesReports')}</span>
  </button>
{/if}
```

### 5. Component
```svelte
<script lang="ts">
  import { hasPermission } from '$lib/utils/permissions';
  import { FUNCTION_CODES } from '$lib/constants/functionCodes';
  
  const canView = hasPermission(FUNCTION_CODES.SALES_REPORTS, 'view');
  const canExport = hasPermission(FUNCTION_CODES.SALES_REPORTS, 'export');
</script>

<div class="sales-reports">
  <h2>Sales Reports</h2>
  
  <!-- Report content -->
  {#if canView}
    <ReportChart data={salesData} />
  {/if}
  
  {#if canExport}
    <button on:click={exportToPDF}>Export PDF</button>
  {/if}
</div>
```

---

## Testing Checklist

After adding a new function, verify:

- [ ] Function appears in `app_functions` table
- [ ] Master Admin has full permissions in `role_permissions`
- [ ] Admin has appropriate permissions in `role_permissions`
- [ ] Function code added to constants file
- [ ] Sidebar menu item shows for authorized users
- [ ] Sidebar menu item hidden for unauthorized users
- [ ] Component action buttons respect permissions
- [ ] Unauthorized access shows "Access Denied" message
- [ ] Translations added for both English and Arabic
- [ ] Permission changes in admin UI affect the new function
- [ ] Direct URL access blocked if no view permission

---

## Quick Reference Scripts

### Script 1: Bulk Insert Multiple Functions

```javascript
// bulk-add-functions.js
const functions = [
  { name: 'Sales Reports', code: 'SALES_REPORTS', desc: 'Sales analytics', cat: 'Reports' },
  { name: 'Inventory Reports', code: 'INVENTORY_REPORTS', desc: 'Stock reports', cat: 'Reports' },
  { name: 'Customer Analytics', code: 'CUSTOMER_ANALYTICS', desc: 'Customer insights', cat: 'Reports' }
];

for (const func of functions) {
  await supabase.from('app_functions').insert({
    function_name: func.name,
    function_code: func.code,
    description: func.desc,
    category: func.cat,
    is_active: true
  });
}
```

### Script 2: Assign Default Permissions to New Functions

```javascript
// assign-default-permissions.js
const functionCodes = ['SALES_REPORTS', 'INVENTORY_REPORTS', 'CUSTOMER_ANALYTICS'];

for (const code of functionCodes) {
  const { data: func } = await supabase
    .from('app_functions')
    .select('id')
    .eq('function_code', code)
    .single();
    
  const { data: roles } = await supabase
    .from('user_roles')
    .select('id, role_code')
    .in('role_code', ['MASTER_ADMIN', 'ADMIN']);
    
  for (const role of roles) {
    await supabase.from('role_permissions').insert({
      role_id: role.id,
      function_id: func.id,
      can_view: true,
      can_add: role.role_code === 'MASTER_ADMIN',
      can_edit: role.role_code === 'MASTER_ADMIN',
      can_delete: role.role_code === 'MASTER_ADMIN',
      can_export: true
    });
  }
}
```

---

## Common Mistakes to Avoid

1. **❌ Forgetting to add role permissions** - Function exists but no one can access it
2. **❌ Wrong function_code format** - Use UPPERCASE_SNAKE_CASE, not camelCase
3. **❌ Not adding to constants file** - Hardcoding strings leads to typos
4. **❌ Missing translations** - Arabic/English labels must both exist
5. **❌ No permission check in component** - Buttons visible to everyone
6. **❌ Not testing with restricted user** - Always test with non-admin account
7. **❌ Duplicate function_code** - Codes must be unique, check before inserting
8. **❌ Wrong category** - Use predefined categories, don't invent new ones

---

## Summary Workflow

```
1. Add to app_functions table → Database
2. Add role_permissions → Database  
3. Add to FUNCTION_CODES → Constants file
4. Add sidebar menu item → Sidebar.svelte (with permission check)
5. Add translations → en.ts + ar.ts
6. Add permission checks → Component (buttons, actions)
7. Test with multiple user roles → Verify enforcement
```

**Time estimate per function: 15-30 minutes**

---

## Support & Troubleshooting

**Problem: Function not showing in admin permission UI**
- Check if `is_active = true` in app_functions table
- Verify admin UI fetches from app_functions dynamically

**Problem: Permission check always returns false**
- Check function_code spelling matches database exactly
- Verify user has role_permissions entry for the function
- Check user_permissions_view includes the function

**Problem: Sidebar item visible to everyone**
- Missing `{#if hasPermission(...)}` wrapper around menu item
- Check permission utility is imported correctly

**Problem: Database insert fails**
- function_code might already exist (must be unique)
- Check all required fields are provided

---

## Version History

- **v1.0** (2025-11-30) - Initial guide created
- Updates will be tracked here as system evolves