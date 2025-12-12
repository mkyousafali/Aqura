# Button Permission System - Implementation Guide

## Overview
This document describes the complete button permission system implementation in the Aqura application, which controls sidebar button visibility based on user permissions stored in the database.

---

## System Architecture

### Database Tables
1. **`sidebar_buttons`** - Contains all available buttons (75 total)
   - Stores button codes (e.g., `AD_MANAGER`, `FLYER_MASTER`, `USER_MANAGEMENT`)
   - Defines button metadata and properties

2. **`button_permissions`** - Controls which buttons are enabled/disabled for each user
   - Links users to buttons
   - Contains `is_enabled` flag for each user-button combination
   - Managed through ButtonAccessControl component

### Frontend Components
1. **`Sidebar.svelte`** - Main navigation sidebar (4588 lines)
   - Loads user's button permissions on mount
   - Checks permissions before rendering each button
   - Contains 75 permission-controlled buttons across 9 sections

2. **`ButtonAccessControl.svelte`** - Admin interface for managing button permissions
   - Allows enabling/disabling buttons per user
   - Updates `button_permissions` table

---

## Implementation Details

### Permission Loading System

```javascript
// Loads all enabled buttons for current user from database
async function loadButtonPermissions() {
    if (!currentUser?.id) return;
    
    try {
        const { data, error } = await supabase
            .from('button_permissions')
            .select('button_code')
            .eq('user_id', currentUser.id)
            .eq('is_enabled', true);  // Only fetch enabled buttons
            
        if (error) throw error;
        
        allowedButtonCodes = new Set(data.map(p => p.button_code));
    } catch (error) {
        console.error('Error loading button permissions:', error);
        allowedButtonCodes = new Set();
    }
}
```

### Permission Check Function

```javascript
// Checks if a button is allowed for current user
function isButtonAllowed(buttonCode: string): boolean {
    return allowedButtonCodes.has(buttonCode);
}
```

### Button Rendering Pattern

```svelte
<!-- Each button is wrapped with permission check -->
{#if isButtonAllowed('BUTTON_CODE')}
    <button on:click={handleButtonClick}>
        <Icon />
        <span>{$t('button.label')}</span>
    </button>
{/if}
```

---

## Complete Button Inventory (75 Buttons)

### 1. Delivery Section (6 buttons)
- `ORDERS_MANAGER` - Orders Manager
- `DELIVERY_SETTINGS` - Delivery Settings
- `START_RECEIVING` - Start Receiving
- `RECEIVING` - Receiving
- `RECEIVING_RECORDS` - Receiving Records
- `WARNING_MASTER` - Warning Master

### 2. Vendor Section (7 buttons)
- `CREATE_VENDOR` - Create Vendor
- `MANAGE_VENDOR` - Manage Vendor
- `UPLOAD_VENDOR` - Upload Vendor
- `VENDOR_RECORDS` - Vendor Records
- `CONTACT_MANAGEMENT` - Contact Management
- `COMMUNICATION_CENTER` - Communication Center
- `DOCUMENT_MANAGEMENT` - Document Management

### 3. Media Section (11 buttons)
- `FLYER_MASTER` - Flyer Master
- `FLYER_TEMPLATES` - Flyer Templates
- `GENERATE_FLYERS` - Generate Flyers
- `FLYER_SETTINGS` - Flyer Settings
- `AD_MANAGER` - Ad Manager
- `OFFER_PRODUCT_EDITOR` - Offer Product Editor
- `CUSTOMER_MASTER` - Customer Master
- `PRICING_MANAGER` - Pricing Manager
- `SHELF_PAPER_MANAGER` - Shelf Paper Manager
- `PRODUCT_MASTER` - Product Master
- `VARIATION_MANAGER` - Variation Manager

### 4. Promo Section (5 buttons)
- `COUPON_DASHBOARD_PROMO` - Coupon Dashboard
- `COUPON_REPORTS` - Coupon Reports
- `CAMPAIGN_MANAGER` - Campaign Manager
- `CUSTOMER_IMPORTER` - Customer Importer
- `PRODUCT_MANAGER_PROMO` - Product Manager

### 5. Finance Section (10 buttons)
- `MONTHLY_MANAGER` - Monthly Manager
- `MONTHLY_BREAKDOWN` - Monthly Breakdown
- `PAID_MANAGER` - Paid Manager
- `EXPENSE_MANAGER` - Expense Manager
- `EXPENSE_TRACKER` - Expense Tracker
- `DAY_BUDGET_PLANNER` - Day Budget Planner
- `OVERDUES_REPORT` - Overdues Report
- `VENDOR_PENDING_PAYMENTS` - Vendor Payments
- `SALES_REPORT` - Sales Report
- `REPORTING_MAP` - Reporting Map

### 6. HR Section (12 buttons)
- `ASSIGN_ROLES` - Assign Roles
- `ASSIGN_POSITIONS` - Assign Positions
- `CREATE_POSITION` - Create Position
- `CREATE_LEVEL` - Create Level
- `CREATE_DEPARTMENT` - Create Department
- `CREATE_USER_ROLES` - Create User Roles
- `SALARY_MANAGEMENT` - Salary Management
- `BIOMETRIC_DATA` - Biometric Data
- `EXPORT_BIOMETRIC_DATA` - Export Biometric Data
- `UPLOAD_EMPLOYEES` - Upload Employees
- `APPROVAL_PERMISSIONS` - Approval Permissions
- `USER_PERMISSIONS` - User Permissions

### 7. Tasks Section (8 buttons)
- `CREATE_TASK` - Create Task
- `VIEW_TASKS` - View Task Templates
- `MY_TASKS` - My Tasks
- `MY_ASSIGNMENTS` - My Assignments
- `BRANCH_PERFORMANCE_WINDOW` - Branch Performance
- `ASSIGN_TASKS` - Assign Tasks
- `TASK_STATUS` - Task Status
- `TASK_MASTER` - Task Master

### 8. Notification Section (1 button)
- `MANUAL_SCHEDULING` - Manual Scheduling

### 9. Users Section (9 buttons)
- `CREATE_USER` - Create User
- `USER_MANAGEMENT` - Users
- `MANAGE_ADMIN_USERS` - Manage Admin Users
- `MANAGE_MASTER_ADMIN` - Manage Master Admin
- `INTERFACE_ACCESS_MANAGER` - Interface Access
- `OFFER_MANAGEMENT` - Offer Management
- `OFFER_MANAGER` - Offer Manager
- `PRODUCTS_MANAGER` - Products Manager
- `CREATE_NEW_OFFER` - Create New Offer

### 10. Controls Section (6 buttons)
- `BUTTON_ACCESS_CONTROL` - Button Access Control
- `BUTTON_GENERATOR` - Button Generator
- `BRANCHES` - Branch Master
- `E_R_P_CONNECTIONS` - ERP Connections
- `SETTINGS` - Sound Settings
- `CLEAR_TABLES` - Clear Tables

---

## How to Add New Buttons (Step-by-Step Guide)

### Step 1: Add Button to Database
Insert the new button into `sidebar_buttons` table:

```sql
INSERT INTO sidebar_buttons (button_code, button_name, section, subsection, description)
VALUES ('NEW_BUTTON_CODE', 'New Button Name', 'Section Name', 'Subsection Name', 'Button description');
```

### Step 2: Add Button to Sidebar.svelte
Locate the appropriate section in `Sidebar.svelte` and add:

```svelte
{#if isButtonAllowed('NEW_BUTTON_CODE')}
    <button
        class="sidebar-button"
        on:click={handleNewButtonClick}
        title={$t('newButton.tooltip')}
    >
        <Icon name="icon-name" class="button-icon" />
        <span class="button-label">{$t('newButton.label')}</span>
    </button>
{/if}
```

### Step 3: Create Button Handler Function
Add the click handler in the same file:

```javascript
function handleNewButtonClick() {
    // Your button logic here
    console.log('New button clicked');
}
```

### Step 4: Add Translations
Update translation files in `src/lib/i18n/`:

```json
{
    "newButton": {
        "label": "New Button",
        "tooltip": "Click to perform action"
    }
}
```

### Step 5: Set Default Permissions
Add default permission records for users:

```sql
-- Enable for specific users
INSERT INTO button_permissions (user_id, button_code, is_enabled)
SELECT id, 'NEW_BUTTON_CODE', true
FROM users
WHERE role = 'admin';

-- Or enable for all users
INSERT INTO button_permissions (user_id, button_code, is_enabled)
SELECT id, 'NEW_BUTTON_CODE', true
FROM users;
```

### Step 6: Test the Implementation
1. Login with a test user
2. Open ButtonAccessControl component
3. Verify new button appears in the list
4. Toggle the button on/off
5. Logout and login again
6. Confirm button visibility matches the enabled state

---

## Important Naming Conventions

### Database Button Codes
- Use **UPPERCASE** with **UNDERSCORES**: `BUTTON_NAME`
- Be specific and descriptive
- Match exactly between database and code

### Common Code Patterns
| Sidebar Code (Old) | Database Code (Correct) |
|-------------------|------------------------|
| `BRANCH_MASTER` | `BRANCHES` |
| `SOUND_SETTINGS` | `SETTINGS` |
| `ERP_CONNECTIONS` | `E_R_P_CONNECTIONS` |
| `USERS` | `USER_MANAGEMENT` |
| `MANAGE_CAMPAIGNS` | `CAMPAIGN_MANAGER` |

**Critical**: Always query the database first to get the exact button code:

```javascript
// Query to check button code in database
const { data } = await supabase
    .from('sidebar_buttons')
    .select('button_code, button_name')
    .eq('button_name', 'Your Button Name')
    .single();

console.log('Use this code:', data.button_code);
```

---

## Troubleshooting

### Button Not Appearing After Adding
1. **Check button_permissions table**:
   ```sql
   SELECT * FROM button_permissions 
   WHERE user_id = 'YOUR_USER_ID' 
   AND button_code = 'YOUR_BUTTON_CODE';
   ```

2. **Verify is_enabled is true**:
   ```sql
   UPDATE button_permissions 
   SET is_enabled = true 
   WHERE user_id = 'YOUR_USER_ID' 
   AND button_code = 'YOUR_BUTTON_CODE';
   ```

3. **Clear cache and reload**: Logout, clear browser cache, login again

4. **Check console for errors**: Open browser DevTools and look for permission loading errors

### Button Showing When It Should Be Hidden
1. **Verify permission check exists**: Search for `isButtonAllowed('BUTTON_CODE')` in Sidebar.svelte
2. **Check code spelling**: Ensure exact match between sidebar and database
3. **Verify query logic**: Confirm `.eq('is_enabled', true)` is present in loadButtonPermissions()

### Permission Changes Not Taking Effect
1. **Refresh button permissions**: Call `loadButtonPermissions()` after changes
2. **Check user session**: Ensure currentUser.id is correct
3. **Verify database update**: Confirm ButtonAccessControl actually updated the record

---

## Implementation History

### Original Issue
- Disabled buttons were showing in sidebar for all sections except Delivery
- Only 7 out of 75 buttons had permission checks implemented
- 68 buttons were visible regardless of permission settings

### Solution Implemented
1. **Added 67 missing permission checks** across 8 sections
2. **Found 2 completely missing buttons**: FLYER_MASTER and BUTTON_GENERATOR
3. **Corrected 19 button code mismatches** between sidebar and database
4. **Achieved 100% synchronization**: All 75 buttons now properly controlled

### Final Verification
```
Database buttons: 75
Sidebar buttons: 75
Missing from sidebar: None - Perfect match!
Extra in sidebar: None - Perfect match!
```

---

## Best Practices

1. **Always use isButtonAllowed()** wrapper for every sidebar button
2. **Query database first** to get exact button codes before implementing
3. **Use consistent naming** between database and sidebar code
4. **Test with multiple users** with different permission levels
5. **Document new buttons** in this file when adding them
6. **Set sensible defaults** when adding new buttons (usually enabled for admins)
7. **Clear cache** when testing permission changes
8. **Verify in ButtonAccessControl** that new buttons appear and can be toggled

---

## Database Access for Verification

Use Supabase service role key to query buttons directly:

```javascript
// Node.js script to verify button codes
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
    'https://supabase.urbanaqura.com',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0'
);

async function getAllButtons() {
    const { data, error } = await supabase
        .from('sidebar_buttons')
        .select('button_code, button_name, section')
        .order('section', { ascending: true })
        .order('button_code', { ascending: true });
    
    if (error) {
        console.error('Error:', error);
        return;
    }
    
    console.log(`Total buttons: ${data.length}`);
    data.forEach(btn => {
        console.log(`${btn.section}: ${btn.button_code} - ${btn.button_name}`);
    });
}

getAllButtons();
```

---

## Maintenance Notes

- **Last Updated**: December 12, 2025
- **Current Button Count**: 75
- **Sections**: 10 (Delivery, Vendor, Media, Promo, Finance, HR, Tasks, Notification, Users, Controls)
- **Implementation Status**: ✅ Complete - All buttons synchronized with database
- **Next Review**: When adding new features that require sidebar buttons

---

## Related Files

- `frontend/src/lib/components/desktop-interface/common/Sidebar.svelte` - Main sidebar component
- `frontend/src/lib/components/desktop-interface/button/ButtonAccessControl.svelte` - Permission management UI
- `supabase/migrations/` - Database schema and RLS policies for button tables
- `BUTTON_401_FIX_COMPLETE.md` - Historical documentation of 401 error fixes
- `BUTTON_RLS_SETUP.md` - Row Level Security setup for button tables

---

## Support

For issues or questions about the button permission system:
1. Check this documentation first
2. Verify database records match sidebar codes
3. Review browser console for error messages
4. Test with different user roles to isolate permission issues
5. Check Supabase logs for database query errors

---

*This system ensures secure, role-based access control for all sidebar navigation buttons in the Aqura application.*
