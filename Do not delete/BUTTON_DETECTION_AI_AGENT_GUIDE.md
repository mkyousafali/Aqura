# Button Detection & Synchronization - AI Agent Guide

## Overview

This guide explains how the button detection system works, how to detect new buttons from the codebase, and how to update endpoints for future maintenance.

## System Architecture

### Core Components

1. **ButtonGenerator Component** (`frontend/src/lib/components/desktop-interface/settings/ButtonGenerator.svelte`)
   - User interface for button synchronization
   - Compares code-based buttons vs database buttons
   - Detects missing and removed buttons
   - Handles automated sync operations

2. **Parse Sidebar Code Endpoint** (`frontend/src/routes/api/parse-sidebar-code/+server.ts`)
   - Parses Sidebar.svelte to extract button structure
   - Returns JSON with sections, subsections, and buttons
   - Source of truth for available buttons in codebase

3. **Database Tables**
   - `sidebar_buttons` - Button records
   - `button_main_sections` - Section definitions
   - `button_sub_sections` - Subsection definitions
   - `button_permissions` - User permissions for buttons

## How Button Detection Works

### Step 1: Parse Sidebar Code

The `/api/parse-sidebar-code` endpoint reads `Sidebar.svelte` and extracts:

```typescript
// Structure returned:
{
  sections: [
    {
      id: "DELIVERY",
      name: "Delivery",
      subsections: [
        {
          id: "delivery_manage",
          name: "Manage",
          buttons: [
            { code: "DELIVERY_DASHBOARD", name: "Delivery Dashboard" },
            { code: "DELIVERY_OPERATIONS", name: "Delivery Operations" }
          ]
        }
      ]
    }
  ]
}
```

**Location in Sidebar.svelte:**
- Search for `isButtonAllowed()` calls
- Each button is wrapped in a conditional check
- Extract button codes (e.g., `DELIVERY_DASHBOARD`)
- Group by section and subsection based on navigation structure

### Step 2: Fetch Database Buttons

ButtonGenerator component queries Supabase:

```typescript
const { data: buttons } = await supabase
  .from('sidebar_buttons')
  .select('*, section:button_main_sections(*), subsection:button_sub_sections(*)')
  .order('section_id')
  .order('subsection_id');
```

### Step 3: Compare & Detect

```typescript
detectMissingButtons() {
  // For each button in codebase:
  // - If NOT in database → status: "missing"
  
  // For each button in database:
  // - If NOT in codebase → status: "removed"
}
```

## Current Button Structure (10 Sections)

### 1. DELIVERY (3 subsections)
- **Manage** (4 buttons): DELIVERY_DASHBOARD, DELIVERY_MANAGE, DELIVERY_EDIT, DELIVERY_DELETE
- **Operations** (2 buttons): DELIVERY_OPERATIONS, DELIVERY_TRACKING
- **Reports** (empty)

### 2. VENDOR (4 subsections)
- **Dashboard** (1 button): VENDOR_DASHBOARD
- **Manage** (3 buttons): VENDOR_MANAGE, VENDOR_CREATE, VENDOR_EDIT
- **Operations** (2 buttons): VENDOR_OPERATIONS, VENDOR_APPROVAL
- **Reports** (1 button): VENDOR_REPORTS

### 3. MEDIA (4 subsections)
- **Dashboard** (1 button): FLYER_MASTER
- **Manage** (6 buttons): PRODUCT_MASTER, VARIATION_MANAGER, OFFER_MANAGER, FLYER_TEMPLATES, FLYER_SETTINGS, SOCIAL_LINK_MANAGER
- **Operations** (5 buttons): OFFER_PRODUCT_EDITOR, CREATE_NEW_OFFER, PRICING_MANAGER, GENERATE_FLYERS, SHELF_PAPER_MANAGER
- **Reports** (empty)

### 4. PROMO (4 subsections)
- **Dashboard** (1 button): COUPON_DASHBOARD_PROMO
- **Manage** (1 button): CAMPAIGN_MANAGER
- **Operations** (3 buttons): VIEW_OFFER_MANAGER, CUSTOMER_IMPORTER, PRODUCT_MANAGER_PROMO
- **Reports** (1 button): PROMO_REPORTS

### 5. FINANCE (4 subsections)
- **Dashboard** (empty)
- **Manage** (1 button): CATEGORY_MANAGER
- **Operations** (5 buttons): EXPENSES_MANAGER, BUDGET_PLANNING, BILL_SCHEDULING, INVOICE_MANAGER, PAYMENT_PROCESSING
- **Reports** (5 buttons): FINANCIAL_REPORTS, ACCOUNT_STATEMENTS, CASH_FLOW_ANALYSIS, AUDIT_TRAIL, EXPENSE_SUMMARY

### 6. HR (4 subsections)
- **Dashboard** (empty)
- **Manage** (10 buttons): HR_MANAGER, EMPLOYEE_MANAGEMENT, SALARY_MANAGEMENT, LEAVE_MANAGEMENT, RECRUITMENT, PERFORMANCE_REVIEW, TRAINING_DEVELOPMENT, ATTENDANCE_SYSTEM, EMPLOYEE_DIRECTORY, BENEFITS_MANAGEMENT
- **Operations** (empty)
- **Reports** (2 buttons): HR_REPORTS, PAYROLL_REPORTS

### 7. TASKS (4 subsections)
- **Dashboard** (1 button): TASK_DASHBOARD
- **Manage** (2 buttons): CREATE_TASK, VIEW_TASKS
- **Operations** (1 button): TASK_OPERATIONS
- **Reports** (4 buttons): TASK_REPORTS, TASK_ANALYTICS, TASK_COMPLETION_RATE, TASK_SUMMARY

### 8. NOTIFICATIONS (4 subsections)
- **Dashboard** (1 button): NOTIFICATIONS_DASHBOARD
- **Manage** (empty)
- **Operations** (empty)
- **Reports** (empty)

### 9. USERS (4 subsections)
- **Dashboard** (1 button): USERS_DASHBOARD
- **Manage** (5 buttons): USER_MANAGEMENT, ROLE_ASSIGNMENT, USER_PERMISSIONS, USER_REGISTRATION, ACCOUNT_RECOVERY
- **Operations** (empty)
- **Reports** (empty)

### 10. CONTROLS (4 subsections)
- **Dashboard** (empty)
- **Manage** (6 buttons): BUTTON_GENERATOR, BUTTON_ACCESS_CONTROL, ROLE_MANAGEMENT, PERMISSION_AUDIT, SECURITY_SETTINGS, SYSTEM_CONFIG
- **Operations** (empty)
- **Reports** (empty)

## How to Add New Buttons

### Method 1: Manual Addition (Quick)

1. **Add button to Sidebar.svelte**
   ```svelte
   {#if isButtonAllowed('YOUR_BUTTON_CODE')}
     <button on:click={() => navigateTo('...')}>Button Name</button>
   {/if}
   ```

2. **Update parse-sidebar-code endpoint**
   - Find the appropriate section/subsection
   - Add button to the structure:
   ```typescript
   buttons: [
     ...existing buttons,
     { code: 'YOUR_BUTTON_CODE', name: 'Button Display Name' }
   ]
   ```

3. **Run Button Sync**
   - Go to Controls > Manage > Button Generator
   - Click "Sync Buttons"
   - The system will:
     - Detect missing buttons
     - Add them to database
     - Create permissions for all users
     - Remove orphaned buttons & permissions

### Method 2: AI Agent Detection (Automated)

For AI agents to detect new buttons:

```typescript
// 1. Parse code for new button patterns
const pattern = /isButtonAllowed\('([A-Z_]+)'\)/g;
const matches = sidebar.matchAll(pattern);

// 2. Extract unique button codes
const newButtons = [...new Set(matches.map(m => m[1]))];

// 3. Compare with current database
const currentButtons = await fetchFromDatabase();
const missingButtons = newButtons.filter(b => !currentButtons.includes(b));

// 4. Update parse-sidebar-code endpoint with new buttons
// 5. Trigger sync endpoint to update database
```

## Updating Endpoints for Future Maintenance

### Adding a New Section

**Step 1: Update parse-sidebar-code endpoint**

```typescript
// In frontend/src/routes/api/parse-sidebar-code/+server.ts

const structure = {
  sections: [
    // ... existing sections
    {
      id: 'NEW_SECTION',
      name: 'New Section Display Name',
      subsections: [
        {
          id: 'new_section_manage',
          name: 'Manage',
          buttons: [
            { code: 'NEW_BUTTON_CODE', name: 'New Button Display Name' }
          ]
        },
        // ... other subsections (Dashboard, Operations, Reports)
      ]
    }
  ]
};
```

**Step 2: Add to Sidebar.svelte**

```svelte
<section>
  <!-- New Section Navigation -->
  {#if isButtonAllowed('NEW_BUTTON_CODE')}
    <button>New Button</button>
  {/if}
</section>
```

**Step 3: Sync via Button Generator**

### Modifying Button Access Control

**Update button_permissions table:**

```sql
-- Enable button for specific user role
INSERT INTO button_permissions (user_id, button_id, is_enabled)
VALUES (user_id, button_id, true);

-- Disable button for specific user
UPDATE button_permissions 
SET is_enabled = false 
WHERE button_id = button_id AND user_id = user_id;
```

### API Endpoints Reference

#### GET /api/parse-sidebar-code
Returns current button structure from Sidebar.svelte

```json
{
  "sections": [
    {
      "id": "SECTION_CODE",
      "name": "Section Name",
      "subsections": [
        {
          "id": "section_subsection",
          "name": "Subsection Name",
          "buttons": [
            { "code": "BUTTON_CODE", "name": "Button Name" }
          ]
        }
      ]
    }
  ]
}
```

#### ButtonGenerator Component Endpoints

**Sync Buttons** (POST - in component)
```typescript
POST /api/parse-sidebar-code
// Triggers database sync
// Actions:
// - Removes orphaned buttons from database
// - Removes orphaned permissions
// - Adds missing buttons to database
// - Creates permissions for all users on new buttons
```

## Maintenance Checklist for AI Agents

When a new feature is added to the codebase:

- [ ] Check if new buttons were added to Sidebar.svelte
- [ ] Verify buttons follow naming convention: `SECTION_FEATURE_ACTION`
- [ ] Update parse-sidebar-code endpoint with new button definitions
- [ ] Run Button Sync in ButtonGenerator UI
- [ ] Verify in database: `SELECT * FROM sidebar_buttons WHERE code LIKE 'NEW_%'`
- [ ] Check button_permissions created for all users
- [ ] Test button visibility with different user roles

## Database Schema Reference

### sidebar_buttons
```sql
id (primary key)
code (unique) - Button identifier
name - Display name
section_id - Foreign key to button_main_sections
subsection_id - Foreign key to button_sub_sections
created_at
updated_at
```

### button_main_sections
```sql
id (primary key)
code - Section identifier
name - Section display name
created_at
```

### button_sub_sections
```sql
id (primary key)
code - Subsection identifier
name - Subsection display name
section_id - Foreign key to button_main_sections
created_at
```

### button_permissions
```sql
id (primary key)
user_id - Foreign key to users
button_id - Foreign key to sidebar_buttons
is_enabled - Boolean
created_at
updated_at
```

## Troubleshooting

### Issue: New buttons not appearing after sync

1. Verify button code in Sidebar.svelte
2. Check parse-sidebar-code endpoint has updated structure
3. Confirm button_permissions were created for target user
4. Check user's role-based access rules

### Issue: Sync removing too many buttons

1. Verify all active buttons are in parse-sidebar-code endpoint
2. Check Sidebar.svelte for commented-out code
3. Review recent code changes for removed features

### Issue: Orphaned permissions not cleaning up

1. Verify button_permissions deletion is enabled in syncButtonsWithDatabase()
2. Check for foreign key constraints
3. Monitor database logs for deletion errors

## Key Files to Monitor

```
frontend/
├── src/
│   ├── lib/
│   │   └── components/
│   │       └── desktop-interface/
│   │           └── settings/
│   │               └── ButtonGenerator.svelte (MAIN COMPONENT)
│   ├── routes/
│   │   └── api/
│   │       └── parse-sidebar-code/
│   │           └── +server.ts (DETECTION ENDPOINT)
│   └── lib/navigation/
│       └── Sidebar.svelte (SOURCE OF TRUTH)
supabase/
├── migrations/ (Button-related RLS policies)
└── schema/ (Button tables)
```

## Future Enhancement Ideas

1. **Automated Button Detection** - Schedule parse-sidebar-code to run daily
2. **Change Log** - Track button additions/removals with timestamps
3. **Role-Based Button Visibility** - Define buttons per role in database
4. **Button Grouping** - Add parent-child relationships for menu items
5. **Feature Flag Integration** - Tie button visibility to feature flags
6. **Audit Trail** - Log who synced buttons and when

---

**Last Updated:** December 30, 2025
**Maintained By:** Development Team / AI Agents
**Related Files:** SIDEBAR_SECTIONS_AND_BUTTONS.md
