# User Permissions System - Complete Setup Documentation

## Table of Contents
1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Permission Types & Actions](#permission-types--actions)
4. [Role Types & User Types](#role-types--user-types)
5. [System Functions (80+ Codes)](#system-functions-80-codes)
6. [Database Schema](#database-schema)
7. [Frontend Components](#frontend-components)
8. [Utility Functions](#utility-functions)
9. [Data Flow & Implementation](#data-flow--implementation)

---

## Overview

The Aqura system implements a comprehensive, role-based access control (RBAC) system with function-level permissions. This system allows fine-grained control over what users can do across the application through a combination of:

- **Function-based permissions**: 80+ defined system functions with granular control
- **Role-based permissions**: Role-to-function mappings stored in database
- **User permissions**: Individual user permission overrides
- **Interface permissions**: Control over desktop/mobile/customer/cashier interface access
- **Approval permissions**: Workflow-specific approval capabilities with amount limits

---

## System Architecture

### Permission Hierarchy

```
User Account (users table)
├── user_type (global/branch_specific/customer)
├── role_type (Master Admin/Admin/Position-based/Customer)
├── position_id → Position details
├── interface_permissions (desktop/mobile/customer/cashier access)
├── approval_permissions (approval workflows)
└── permissions (JSON field: explicit per-function permissions)
    └── Falls back to user_roles → role_permissions (role-based defaults)
```

### Permission Resolution Flow

1. Check user's explicit `permissions` field (users.permissions JSONB)
2. If not found, fall back to user's `role_type`
3. If Master Admin → All permissions granted
4. If Admin → Most permissions granted (except delete in some cases)
5. If Position-based → Check role_permissions table for specific function

---

## Permission Types & Actions

### Permission Actions (5-Action Matrix)

Each function has up to 5 distinct permission types:

| Action | Code | Database Column | Meaning |
|--------|------|-----------------|---------|
| View | `can_view` | `can_view` | Can see/access the feature |
| Create/Add | `can_add` | `can_add` | Can create new records |
| Edit/Update | `can_edit` | `can_edit` | Can modify existing records |
| Delete | `can_delete` | `can_delete` | Can delete records |
| Export | `can_export` | `can_export` | Can export data |

**Usage Example:**
```typescript
hasPermission('USER_MANAGEMENT', 'can_view')      // Can see user list?
hasPermission('USER_MANAGEMENT', 'can_add')       // Can create new user?
hasPermission('USER_MANAGEMENT', 'can_edit')      // Can edit user details?
hasPermission('USER_MANAGEMENT', 'can_delete')    // Can delete user?
hasPermission('USER_MANAGEMENT', 'can_export')    // Can export users?
```

---

## Role Types & User Types

### Role Types (4 Levels)

| Role Type | Code | Permissions | Usage |
|-----------|------|-------------|-------|
| Master Admin | `Master Admin` | All functions, all actions | System administrator |
| Admin | `Admin` | Most functions, restricted delete | Branch/functional administrator |
| Position-based | `Position-based` | Based on assigned position & role_permissions | Regular employees |
| Customer | `Customer` | Customer app specific functions | End customers |

### User Types (3 Categories)

| User Type | Code | Scope | Details |
|-----------|------|-------|---------|
| Global | `global` | System-wide access | Access to all branches |
| Branch-specific | `branch_specific` | Single or multiple branches | Limited to assigned branches only |
| Customer | `customer` | Customer application only | Cannot access admin/staff features |

---

## System Functions (80+ Codes)

The system defines 80+ function codes across multiple categories. Each function maps to a business capability and can be controlled with the 5-action permission matrix.

### Complete Function Codes List

#### Administration Functions (15)

| Function Code | Display Name | Category | Usage |
|---------------|--------------|----------|-------|
| USER_MANAGEMENT | User Management | Administration | Create, edit, delete users |
| ROLE_MANAGEMENT | Role Management | Administration | Create and manage roles |
| PERMISSION_MANAGEMENT | Permission Management | Administration | Assign permissions to users/roles |
| BRANCH_MANAGEMENT | Branch Management | Administration | Create and manage branches |
| SYSTEM_SETTINGS | System Settings | Administration | Configure system parameters |
| AUDIT_LOGS | Audit Logs | Administration | View system activity logs |
| NOTIFICATION_MANAGEMENT | Notification Management | Administration | Create and send notifications |
| EMPLOYEE_MANAGEMENT | Employee Management | Administration | Manage employee records |
| DEPARTMENT_MANAGEMENT | Department Management | Administration | Create and manage departments |
| POSITION_MANAGEMENT | Position Management | Administration | Create and manage positions |
| APPROVAL_WORKFLOW | Approval Workflow | Administration | Configure approval rules |
| INTERFACE_PERMISSIONS | Interface Permissions | Administration | Control UI access (desktop/mobile/customer/cashier) |
| BIOMETRIC_MANAGEMENT | Biometric Management | Administration | Manage biometric device connections |
| ERP_CONNECTION | ERP Connection | Administration | Manage ERP system connections |
| BACKUP_RESTORE | Backup & Restore | Administration | System backup and recovery |

#### Master Data Functions (12)

| Function Code | Display Name | Category | Usage |
|---------------|--------------|----------|-------|
| PRODUCT_MANAGEMENT | Product Management | Master Data | Create and manage products |
| CATEGORY_MANAGEMENT | Category Management | Master Data | Create product categories |
| UNIT_MANAGEMENT | Unit Management | Master Data | Create measurement units |
| TAX_MANAGEMENT | Tax Management | Master Data | Create and manage tax categories |
| VENDOR_MANAGEMENT | Vendor Management | Master Data | Create and manage vendors |
| CUSTOMER_MANAGEMENT | Customer Management | Master Data | Create and manage customers |
| PRICE_MANAGEMENT | Price Management | Master Data | Set and manage product prices |
| DISCOUNT_MANAGEMENT | Discount Management | Master Data | Create and manage discounts |
| STORAGE_MANAGEMENT | Storage Management | Master Data | Manage warehouse/storage locations |
| DELIVERY_SETTINGS | Delivery Settings | Master Data | Configure delivery service settings |
| PAYMENT_TERMS | Payment Terms | Master Data | Set payment terms and conditions |
| VEHICLE_MANAGEMENT | Vehicle Management | Master Data | Manage delivery vehicles |

#### Operations Functions (18)

| Function Code | Display Name | Category | Usage |
|---------------|--------------|----------|-------|
| RECEIVING_MANAGEMENT | Receiving Management | Operations | Manage incoming goods |
| STOCK_MANAGEMENT | Stock Management | Operations | View and manage inventory |
| STOCK_TRANSFER | Stock Transfer | Operations | Transfer stock between locations |
| PICKING | Picking | Operations | Pick items for orders |
| PACKING | Packing | Operations | Pack items for delivery |
| DELIVERY_MANAGEMENT | Delivery Management | Operations | Manage deliveries |
| RETURN_MANAGEMENT | Return Management | Operations | Process returns |
| DAMAGE_MANAGEMENT | Damage Management | Operations | Record and process damaged items |
| QUALITY_CONTROL | Quality Control | Operations | Perform quality checks |
| SHELF_PAPER | Shelf Paper | Operations | Print and manage shelf papers |
| BARCODE_MANAGEMENT | Barcode Management | Operations | Manage product barcodes |
| COUPON_MANAGEMENT | Coupon Management | Operations | Create and manage coupons |
| FLYER_MANAGEMENT | Flyer Management | Operations | Create and manage promotional flyers |
| OFFER_MANAGEMENT | Offer Management | Operations | Create and manage special offers |
| BUNDLE_MANAGEMENT | Bundle Management | Operations | Create product bundles |
| BOGO_MANAGEMENT | Buy One Get One Management | Operations | Create BOGO promotions |
| TASK_MANAGEMENT | Task Management | Operations | Create and assign tasks |
| QUICK_TASK_MANAGEMENT | Quick Task Management | Operations | Manage quick tasks |

#### Finance Functions (18)

| Function Code | Display Name | Category | Usage |
|---------------|--------------|----------|-------|
| ORDER_MANAGEMENT | Order Management | Finance | Create and manage orders |
| SALES_REPORTS | Sales Reports | Finance | View sales analytics |
| PAYMENT_PROCESSING | Payment Processing | Finance | Process customer payments |
| INVOICE_MANAGEMENT | Invoice Management | Finance | Create and manage invoices |
| REFUND_PROCESSING | Refund Processing | Finance | Process refunds |
| REQUISITION_APPROVAL | Requisition Approval | Finance | Approve expense requisitions |
| EXPENSE_MANAGEMENT | Expense Management | Finance | Create and manage expenses |
| BILL_APPROVAL | Bill Approval | Finance | Approve vendor bills |
| RECURRING_BILL | Recurring Bill Management | Finance | Manage recurring bills |
| VENDOR_PAYMENT | Vendor Payment | Finance | Process vendor payments |
| FINANCIAL_REPORTS | Financial Reports | Finance | View financial analytics |
| CASH_REGISTER | Cash Register | Finance | Manage cash transactions |
| ACCOUNTING | Accounting | Finance | General accounting functions |
| LEAVE_REQUEST | Leave Request Management | Finance | Approve leave requests |
| SALARY_MANAGEMENT | Salary Management | Finance | Manage employee salaries |
| COMMISSION_MANAGEMENT | Commission Management | Finance | Calculate and manage commissions |
| BONUS_MANAGEMENT | Bonus Management | Finance | Manage employee bonuses |
| PAYROLL | Payroll | Finance | Process payroll |

#### Customer Functions (8)

| Function Code | Display Name | Category | Usage |
|---------------|--------------|----------|-------|
| CUSTOMER_ORDERS | Customer Orders | Customer | View customer orders |
| CUSTOMER_PROFILE | Customer Profile | Customer | View/edit customer profile |
| CUSTOMER_HISTORY | Customer History | Customer | View customer purchase history |
| CUSTOMER_SUPPORT | Customer Support | Customer | Provide customer support |
| LOYALTY_PROGRAM | Loyalty Program | Customer | Manage customer loyalty |
| CUSTOMER_SEGMENTATION | Customer Segmentation | Customer | Segment customers |
| CUSTOMER_FEEDBACK | Customer Feedback | Customer | Collect customer feedback |
| CUSTOMER_RECOVERY | Customer Recovery | Customer | Handle customer account recovery |

#### Product Functions (5)

| Function Code | Display Name | Category | Usage |
|---------------|--------------|----------|-------|
| PRODUCT_IMPORT | Product Import | Product | Import products from ERP |
| PRODUCT_EXPORT | Product Export | Product | Export product data |
| PRODUCT_VARIATION | Product Variation | Product | Manage product variations |
| PRODUCT_BUNDLE | Product Bundle | Product | Create product bundles |
| PRODUCT_SYNC | Product Sync | Product | Sync products with ERP |

#### Offers & Promotions Functions (4)

| Function Code | Display Name | Category | Usage |
|---------------|--------------|----------|-------|
| OFFER_CREATE | Create Offers | Offers | Create promotional offers |
| OFFER_APPROVE | Approve Offers | Offers | Approve pending offers |
| OFFER_ANALYTICS | Offer Analytics | Offers | View offer performance |
| OFFER_TEMPLATES | Offer Templates | Offers | Create offer templates |

#### Notifications Functions (2)

| Function Code | Display Name | Category | Usage |
|---------------|--------------|----------|-------|
| NOTIFICATION_CREATE | Create Notifications | Notifications | Create notifications |
| NOTIFICATION_VIEW | View Notifications | Notifications | View all notifications |

#### Reports Functions (2)

| Function Code | Display Name | Category | Usage |
|---------------|--------------|----------|-------|
| REPORT_GENERATION | Report Generation | Reports | Generate custom reports |
| REPORT_SCHEDULING | Report Scheduling | Reports | Schedule automated reports |

#### System Functions (2)

| Function Code | Display Name | Category | Usage |
|---------------|--------------|----------|-------|
| SYSTEM_MAINTENANCE | System Maintenance | System | Perform system maintenance |
| DATA_IMPORT_EXPORT | Data Import/Export | System | Import/export system data |

**Total: 86 Functions** across 13 categories

---

## Database Schema

### 1. app_functions Table

**Purpose:** Catalog of all system functions that require permission control

**Total Columns:** 8

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | uuid | ✗ No | `uuid_generate_v4()` | Primary key - unique function identifier |
| `function_name` | varchar | ✗ No | - | Display name of the function |
| `function_code` | varchar | ✗ No | - | Unique code identifier for function (e.g., 'USER_MANAGEMENT') |
| `description` | text | ✓ Yes | - | Detailed description of what the function does |
| `category` | varchar | ✓ Yes | - | Function category (Administration, Master Data, Operations, etc.) |
| `is_active` | boolean | ✓ Yes | true | Whether function is available for permission control |
| `created_at` | timestamp with time zone | ✓ Yes | now() | Record creation timestamp |
| `updated_at` | timestamp with time zone | ✓ Yes | now() | Record last update timestamp |

**Relationships:**
- Referenced by `role_permissions.function_id` (one-to-many)
- Referenced by `approval_permissions` (for approval-specific functions)

**Example Records:**
```sql
-- User Management Function
INSERT INTO app_functions (id, function_name, function_code, description, category)
VALUES (uuid1, 'User Management', 'USER_MANAGEMENT', 'Create, edit, and delete users', 'Administration');

-- Product Management Function
INSERT INTO app_functions (id, function_name, function_code, description, category)
VALUES (uuid2, 'Product Management', 'PRODUCT_MANAGEMENT', 'Create and manage products', 'Master Data');
```

---

### 2. role_permissions Table

**Purpose:** Maps roles to functions with granular 5-action permission matrix

**Total Columns:** 10

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | uuid | ✗ No | `uuid_generate_v4()` | Primary key - unique role-function permission entry |
| `role_id` | uuid | ✗ No | - | Foreign key to `user_roles.id` |
| `function_id` | uuid | ✗ No | - | Foreign key to `app_functions.id` |
| `can_view` | boolean | ✓ Yes | false | Permission to view/access the function |
| `can_add` | boolean | ✓ Yes | false | Permission to create new records |
| `can_edit` | boolean | ✓ Yes | false | Permission to modify existing records |
| `can_delete` | boolean | ✓ Yes | false | Permission to delete records |
| `can_export` | boolean | ✓ Yes | false | Permission to export data |
| `created_at` | timestamp with time zone | ✓ Yes | now() | Record creation timestamp |
| `updated_at` | timestamp with time zone | ✓ Yes | now() | Record last update timestamp |

**Constraints:**
- Composite unique key: `(role_id, function_id)` - one permission entry per role-function pair
- Foreign key: `role_id` references `user_roles.id` on delete cascade
- Foreign key: `function_id` references `app_functions.id` on delete cascade

**Expected Data Population:**
- Master Admin role: ~86 functions × all 5 permissions = true (full access)
- Admin role: ~86 functions × view/add/edit/export = true, delete = false
- Position-based roles: Varies per position

**Example Records:**
```sql
-- Master Admin has full permissions on User Management
INSERT INTO role_permissions 
(id, role_id, function_id, can_view, can_add, can_edit, can_delete, can_export)
VALUES (
  uuid1, 
  master_admin_role_id, 
  user_mgmt_func_id, 
  true, true, true, true, true
);

-- Admin has no delete permission
INSERT INTO role_permissions 
(id, role_id, function_id, can_view, can_add, can_edit, can_delete, can_export)
VALUES (
  uuid2, 
  admin_role_id, 
  user_mgmt_func_id, 
  true, true, true, false, true
);

-- Position-based role (e.g., Cashier) has limited permissions
INSERT INTO role_permissions 
(id, role_id, function_id, can_view, can_add, can_edit, can_delete, can_export)
VALUES (
  uuid3, 
  cashier_role_id, 
  sales_func_id, 
  true, true, false, false, false
);
```

---

### 3. user_roles Table

**Purpose:** Defines all available roles in the system

**Total Columns:** 10

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | uuid | ✗ No | `uuid_generate_v4()` | Primary key - unique role identifier |
| `role_name` | varchar | ✗ No | - | Display name of the role (e.g., 'Master Administrator') |
| `role_code` | varchar | ✗ No | - | Unique code identifier (e.g., 'MASTER_ADMIN') |
| `description` | text | ✓ Yes | - | Detailed description of role's responsibilities |
| `is_system_role` | boolean | ✓ Yes | false | Whether this is a system-defined role (not custom) |
| `is_active` | boolean | ✓ Yes | true | Whether role is available for assignment |
| `created_at` | timestamp with time zone | ✓ Yes | now() | Record creation timestamp |
| `updated_at` | timestamp with time zone | ✓ Yes | now() | Record last update timestamp |
| `created_by` | uuid | ✓ Yes | - | Foreign key to `users.id` - who created this role |
| `updated_by` | uuid | ✓ Yes | - | Foreign key to `users.id` - who last updated this role |

**System Roles (Pre-populated):**
```
1. MASTER_ADMIN - Master Administrator (is_system_role = true)
   - Full access to all functions
   - Can manage all users and roles
   - Can configure system settings

2. ADMIN - Administrator (is_system_role = true)
   - Access to most functions
   - Cannot delete certain critical records
   - Can manage users and roles under their branch

3. POSITION_BASED - Custom Position-based Roles (is_system_role = false)
   - Created for specific positions (Cashier, Picker, Packer, etc.)
   - Permissions defined in role_permissions table
   - Can be created and modified as needed
```

**Relationships:**
- Referenced by `role_permissions.role_id` (one-to-many)
- Referenced by `users.role_type` (via role lookup)
- Created/Updated by users in `users` table (one-to-many)

---

### 4. users Table (Permission-Related Columns Only)

**Purpose:** User accounts with permission assignment and role tracking

**Total Columns:** 28 (showing permission-relevant)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | uuid | ✗ No | `uuid_generate_v4()` | Primary key - unique user identifier |
| `username` | varchar | ✗ No | - | Unique login username |
| `password_hash` | varchar | ✗ No | - | Bcrypt hashed password |
| `salt` | varchar | ✗ No | - | Password salt for hashing |
| `quick_access_code` | varchar | ✗ No | - | PIN code for quick login |
| `quick_access_salt` | varchar | ✗ No | - | Salt for quick access code |
| `user_type` | enum (user_type_enum) | ✗ No | 'branch_specific' | User scope (global/branch_specific/customer) |
| `employee_id` | uuid | ✓ Yes | - | Foreign key to `hr_employees.id` |
| `branch_id` | bigint | ✓ Yes | - | Foreign key to `branches.id` - primary branch assignment |
| `role_type` | enum (role_type_enum) | ✓ Yes | 'Position-based' | Role level (Master Admin/Admin/Position-based/Customer) |
| `position_id` | uuid | ✓ Yes | - | Foreign key to `hr_positions.id` - for position-based role lookup |
| `avatar` | text | ✓ Yes | - | User profile image URL |
| `avatar_small_url` | text | ✓ Yes | - | Small avatar image URL |
| `avatar_medium_url` | text | ✓ Yes | - | Medium avatar image URL |
| `avatar_large_url` | text | ✓ Yes | - | Large avatar image URL |
| `is_first_login` | boolean | ✓ Yes | true | Whether user has completed initial login |
| `failed_login_attempts` | integer | ✓ Yes | 0 | Count of failed login attempts (for lockout) |
| `locked_at` | timestamp with time zone | ✓ Yes | - | When account was locked (if at all) |
| `locked_by` | uuid | ✓ Yes | - | Foreign key to `users.id` - who locked this account |
| `last_login_at` | timestamp with time zone | ✓ Yes | - | Last successful login timestamp |
| `password_expires_at` | timestamp with time zone | ✓ Yes | - | When password expires and reset is required |
| `last_password_change` | timestamp with time zone | ✓ Yes | now() | Last password change timestamp |
| `created_by` | bigint | ✓ Yes | - | Foreign key to `users.id` - who created this account |
| `updated_by` | bigint | ✓ Yes | - | Foreign key to `users.id` - who last updated this account |
| `created_at` | timestamp with time zone | ✓ Yes | now() | Record creation timestamp |
| `updated_at` | timestamp with time zone | ✓ Yes | now() | Record last update timestamp |
| `status` | varchar | ✗ No | 'active' | Account status (active/inactive/suspended) |
| `ai_translation_enabled` | boolean | ✗ No | false | Whether AI translation features are enabled |

**Permission Resolution Logic:**
```
When checking if user can perform action:

1. IF user has explicit permissions in permissions field
   → Use that permission
ELSE IF role_type === 'Master Admin'
   → Grant all permissions
ELSE IF role_type === 'Admin'
   → Grant all permissions except delete (in most cases)
ELSE IF role_type === 'Position-based'
   → Look up position_id → hr_positions
   → Find role_permissions for that position
   → Use those permissions
ELSE
   → No permission (default deny)
```

**Relationships:**
- `employee_id` references `hr_employees.id`
- `branch_id` references `branches.id`
- `position_id` references `hr_positions.id`
- `created_by` and `updated_by` reference `users.id` (self-referential)
- Referenced by `interface_permissions.user_id` (one-to-one)
- Referenced by `approval_permissions.user_id` (one-to-one)
- Referenced by `user_audit_logs.user_id` (one-to-many)

---

### 5. interface_permissions Table

**Purpose:** Controls access to different application interfaces

**Total Columns:** 10

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | uuid | ✗ No | `gen_random_uuid()` | Primary key - unique interface permission entry |
| `user_id` | uuid | ✗ No | - | Foreign key to `users.id` - which user |
| `desktop_enabled` | boolean | ✗ No | true | Can user access desktop application? |
| `mobile_enabled` | boolean | ✗ No | true | Can user access mobile application? |
| `customer_enabled` | boolean | ✗ No | false | Can user access customer portal? |
| `cashier_enabled` | boolean | ✓ Yes | false | Can user access cashier interface? |
| `updated_by` | uuid | ✗ No | - | Foreign key to `users.id` - who last updated |
| `notes` | text | ✓ Yes | - | Admin notes about interface restrictions |
| `created_at` | timestamp with time zone | ✓ Yes | now() | Record creation timestamp |
| `updated_at` | timestamp with time zone | ✓ Yes | now() | Record last update timestamp |

**Default Access Pattern:**
```
Master Admin/Admin:
  - desktop_enabled: true
  - mobile_enabled: true
  - customer_enabled: false
  - cashier_enabled: true

Regular Employee:
  - desktop_enabled: true
  - mobile_enabled: true
  - customer_enabled: false
  - cashier_enabled: false (unless assigned)

Customer User:
  - desktop_enabled: false
  - mobile_enabled: false
  - customer_enabled: true
  - cashier_enabled: false
```

**Constraints:**
- Unique key: `(user_id)` - one interface permission set per user
- Foreign key: `user_id` references `users.id` on delete cascade

**Usage Flow:**
1. After login, load this table for authenticated user
2. Check which interfaces user can access
3. Route accordingly in frontend UI
4. Prevent access to disabled interfaces

---

### 6. approval_permissions Table

**Purpose:** Workflow-specific approval permissions with amount limits

**Total Columns:** 18

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `id` | bigint | ✗ No | `nextval('approval_permissions_id_seq')` | Primary key - unique approval permission entry |
| `user_id` | uuid | ✗ No | - | Foreign key to `users.id` - which user can approve |
| `can_approve_requisitions` | boolean | ✗ No | false | Can approve expense requisitions? |
| `requisition_amount_limit` | numeric | ✓ Yes | 0.00 | Maximum requisition amount user can approve |
| `can_approve_single_bill` | boolean | ✗ No | false | Can approve single vendor bills? |
| `single_bill_amount_limit` | numeric | ✓ Yes | 0.00 | Maximum single bill amount user can approve |
| `can_approve_multiple_bill` | boolean | ✗ No | false | Can approve multiple bills at once? |
| `multiple_bill_amount_limit` | numeric | ✓ Yes | 0.00 | Maximum total amount for multiple bills |
| `can_approve_recurring_bill` | boolean | ✗ No | false | Can approve recurring vendor bills? |
| `recurring_bill_amount_limit` | numeric | ✓ Yes | 0.00 | Maximum recurring bill amount |
| `can_approve_vendor_payments` | boolean | ✗ No | false | Can approve vendor payments? |
| `vendor_payment_amount_limit` | numeric | ✓ Yes | 0.00 | Maximum vendor payment amount |
| `can_approve_leave_requests` | boolean | ✗ No | false | Can approve employee leave requests? |
| `created_at` | timestamp with time zone | ✓ Yes | now() | Record creation timestamp |
| `updated_at` | timestamp with time zone | ✓ Yes | now() | Record last update timestamp |
| `created_by` | uuid | ✓ Yes | - | Foreign key to `users.id` - who created record |
| `updated_by` | uuid | ✓ Yes | - | Foreign key to `users.id` - who last updated |
| `is_active` | boolean | ✗ No | true | Whether these approval permissions are active |

**Approval Logic:**
```
When user attempts to approve:
1. Check can_approve_[type] = true
2. Check request_amount <= [type]_amount_limit
3. Grant or deny based on both conditions

Example: Approve $5000 requisition
- can_approve_requisitions: true
- requisition_amount_limit: 10000
→ APPROVED (amount under limit)

Example: Approve $15000 requisition
- can_approve_requisitions: true
- requisition_amount_limit: 10000
→ DENIED (amount exceeds limit, needs higher authority)
```

**Constraints:**
- Unique key: `(user_id)` - one approval permission set per user
- Foreign key: `user_id` references `users.id` on delete cascade

**Typical Setup:**
```
Level 1 Approver:
- can_approve_requisitions: true, limit: $500
- can_approve_single_bill: true, limit: $1000
- can_approve_vendor_payments: true, limit: $500

Level 2 Approver:
- can_approve_requisitions: true, limit: $5000
- can_approve_single_bill: true, limit: $10000
- can_approve_vendor_payments: true, limit: $5000

Director/Manager:
- can_approve_requisitions: true, limit: $50000
- can_approve_single_bill: true, limit: $100000
- can_approve_vendor_payments: true, limit: $50000
```

---

## Frontend Components

### Component: PermissionManager.svelte

**Location:** `frontend/src/lib/components/desktop-interface/settings/user/`

**Purpose:** Master Admin tool for assigning individual user permissions

**Features:**
- Search and select users
- Display function permission matrix
- Toggle individual permissions (view/add/edit/delete/export)
- Select all/deselect all functions
- Save user-specific permissions

**Access Control:** Master Admin only

**Data Loaded:**
- All available functions from `app_functions` table
- Selected user's current permissions from `users.permissions`
- Available users from `users` table

**Actions Performed:**
- Create/update `users.permissions` JSON field
- Records logged in `user_audit_logs`

**API Endpoints Used:**
- `GET /api/functions/all` - List all functions
- `GET /api/users/[id]/permissions` - Get user's current permissions
- `POST /api/users/[id]/permissions` - Update user permissions
- `GET /api/users` - List users

---

### Component: CreateUserRoles.svelte

**Location:** `frontend/src/lib/components/desktop-interface/settings/user/`

**Purpose:** Create custom position-based roles with specific permission combinations

**Features:**
- Create new custom role
- Set role name and description
- Assign position (e.g., Cashier, Picker, Packer)
- Define permission matrix (5 actions across 80+ functions)
- Category-based permission selection
- Bulk assign permissions by category

**Access Control:** Master Admin only

**Data Loaded:**
- All available functions grouped by category
- Available positions from `hr_positions` table
- System functions shown (~15 key functions in UI)

**Actions Performed:**
- Create new `user_roles` record
- Create `role_permissions` entries (one per function)
- Records logged in `user_audit_logs`

**Permission Categories in UI:**
- User Management
- Inventory Management
- Sales Transactions
- Financial Reports
- Customer Management
- Task Management

**API Endpoints Used:**
- `POST /api/roles` - Create new role
- `POST /api/role-permissions/bulk` - Bulk create role permissions
- `GET /api/positions` - List available positions
- `GET /api/functions/all` - List functions by category

---

### Component: AssignRoles.svelte

**Location:** `frontend/src/lib/components/desktop-interface/settings/user/`

**Purpose:** Assign roles to individual users

**Features:**
- Select user to assign roles to
- Display all available roles with descriptions
- Show custom permissions for each role
- Assign role to user
- Display permission categories user will receive
- Prevent assigning higher roles to lower authority users

**Access Control:** Master Admin only (with hierarchy check)

**Data Loaded:**
- List of users from `users` table
- All roles from `user_roles` table
- Role permissions from `role_permissions` table
- User's current role from `users.role_type`

**Actions Performed:**
- Update `users.role_type`
- Update `users.position_id` (if position-based role)
- Records logged in `user_audit_logs`

**Hierarchy Rules:**
```
Master Admin can assign: Any role to any user
Admin cannot assign:     Roles to users with Admin or Master Admin roles
Position-based role:     Cannot assign to other users
Customer role:           Cannot assign to staff users
```

**API Endpoints Used:**
- `GET /api/users` - List users
- `GET /api/roles` - List roles
- `GET /api/roles/[id]/permissions` - Get role's permissions
- `POST /api/users/[id]/role` - Assign role to user

---

### Component: UserPermissionsWindow.svelte

**Location:** `frontend/src/lib/components/desktop-interface/settings/user/`

**Purpose:** View and manage granular permissions for selected users by branch

**Features:**
- Filter users by branch
- Select user to manage
- Display all functions with current permission state
- Toggle individual permissions (view/add/edit/delete/export)
- Per-function permission control
- Permission override system

**Access Control:** Master Admin, Admin

**Data Structures:**
```typescript
interface FunctionWithPermissions {
  id: uuid;
  function_code: string;
  function_name: string;
  category: string;
  permissions: {
    can_view: boolean;
    can_add: boolean;
    can_edit: boolean;
    can_delete: boolean;
    can_export: boolean;
  };
}

interface UserPermissions {
  [functionCode: string]: {
    can_view: boolean;
    can_add: boolean;
    can_edit: boolean;
    can_delete: boolean;
    can_export: boolean;
  };
}
```

**Data Loaded:**
- All functions from `app_functions` table
- User's branch from `users.branch_id`
- Selected user's permissions from `users.permissions`
- Available users filtered by branch

**Actions Performed:**
- Update `users.permissions` JSON field
- Immediate save (auto-save on toggle)
- Records logged in `user_audit_logs`

**UI Layout:**
- Branch selector (dropdown)
- User selector (filtered list)
- Functions list (organized by category)
- Permission toggles (5 checkboxes per function)

**API Endpoints Used:**
- `GET /api/branches` - List branches
- `GET /api/users/branch/[id]` - List users in branch
- `GET /api/functions/all` - List all functions
- `GET /api/users/[id]/permissions` - Get user permissions
- `PUT /api/users/[id]/permissions` - Update user permissions

---

## Utility Functions

### File: permissions.ts

**Location:** `frontend/src/lib/utils/permissions.ts`

**Purpose:** Central permission checking utility - single source of truth for permission logic

### Function: hasPermission()

```typescript
function hasPermission(functionCode: string, action: PermissionAction): boolean
```

**Description:** Checks if current user has permission for a specific function and action

**Parameters:**
- `functionCode` (string): Code of function to check (e.g., 'USER_MANAGEMENT')
- `action` (PermissionAction): Action to check ('can_view' | 'can_add' | 'can_edit' | 'can_delete' | 'can_export')

**Returns:** boolean - true if permission granted, false otherwise

**Logic Flow:**
```
1. Get current user from store
2. If user not authenticated → return false
3. If user.permissions[functionCode] exists → use that permission value
4. Else if user.roleType === 'Master Admin' → return true
5. Else if user.roleType === 'Admin' → return true (except delete restricted)
6. Else → return false (default deny)
```

**Usage Examples:**
```typescript
// Check if user can view products
if (hasPermission('PRODUCT_MANAGEMENT', 'can_view')) {
  // Show product list
}

// Check if user can create users
if (hasPermission('USER_MANAGEMENT', 'can_add')) {
  // Show create user button
}

// Check if user can delete orders
if (hasPermission('ORDER_MANAGEMENT', 'can_delete')) {
  // Show delete button
}
```

---

### Function: canView()

```typescript
function canView(functionCode: string): boolean
```

**Description:** Shorthand for checking view permission

**Returns:** `hasPermission(functionCode, 'can_view')`

**Usage:**
```typescript
if (canView('USER_MANAGEMENT')) {
  // Show user management section
}
```

---

### Function: canCreate() / canAdd()

```typescript
function canCreate(functionCode: string): boolean
function canAdd(functionCode: string): boolean  // alias
```

**Description:** Shorthand for checking create/add permission

**Returns:** `hasPermission(functionCode, 'can_add')`

**Usage:**
```typescript
if (canCreate('PRODUCT_MANAGEMENT')) {
  // Show "New Product" button
}
```

---

### Function: canEdit()

```typescript
function canEdit(functionCode: string): boolean
```

**Description:** Shorthand for checking edit permission

**Returns:** `hasPermission(functionCode, 'can_edit')`

**Usage:**
```typescript
if (canEdit('PRODUCT_MANAGEMENT')) {
  // Show edit button on product card
}
```

---

### Function: canDelete()

```typescript
function canDelete(functionCode: string): boolean
```

**Description:** Shorthand for checking delete permission

**Returns:** `hasPermission(functionCode, 'can_delete')`

**Usage:**
```typescript
if (canDelete('USER_MANAGEMENT')) {
  // Show delete button on user row
}
```

---

### Function: canExport()

```typescript
function canExport(functionCode: string): boolean
```

**Description:** Shorthand for checking export permission

**Returns:** `hasPermission(functionCode, 'can_export')`

**Usage:**
```typescript
if (canExport('SALES_REPORTS')) {
  // Show "Export to Excel" button
}
```

---

### Function: getPermissions()

```typescript
function getPermissions(functionCode: string): PermissionActions
```

**Description:** Get all 5 permission states for a specific function

**Returns:** Object with all permission boolean values

**Return Type:**
```typescript
interface PermissionActions {
  can_view: boolean;
  can_add: boolean;
  can_edit: boolean;
  can_delete: boolean;
  can_export: boolean;
}
```

**Usage:**
```typescript
const perms = getPermissions('USER_MANAGEMENT');
console.log(perms);
// {
//   can_view: true,
//   can_add: true,
//   can_edit: true,
//   can_delete: false,
//   can_export: true
// }
```

---

### Function: getAccessibleFunctions()

```typescript
function getAccessibleFunctions(): string[]
```

**Description:** Get list of all function codes user can access (at least view)

**Returns:** Array of function codes user has at least 'can_view' permission

**Usage:**
```typescript
const accessible = getAccessibleFunctions();
// ['USER_MANAGEMENT', 'PRODUCT_MANAGEMENT', 'SALES_REPORTS', ...]

// Can be used to:
// - Filter available features in UI
// - Determine dashboard widgets to show
// - Filter navigation menu items
```

---

### Function: isMasterAdmin()

```typescript
function isMasterAdmin(): boolean
```

**Description:** Check if current user is Master Admin

**Returns:** true if user.roleType === 'Master Admin'

**Usage:**
```typescript
if (isMasterAdmin()) {
  // Show admin-only features
  // Enable system configuration buttons
}
```

---

### Function: isAdmin()

```typescript
function isAdmin(): boolean
```

**Description:** Check if current user is Admin

**Returns:** true if user.roleType === 'Admin'

**Usage:**
```typescript
if (isAdmin() || isMasterAdmin()) {
  // Show admin features
}
```

---

### Function: getUserRole()

```typescript
function getUserRole(): string | null
```

**Description:** Get current user's role type

**Returns:** User's roleType string or null if not authenticated

**Usage:**
```typescript
const role = getUserRole();
// 'Master Admin', 'Admin', 'Position-based', 'Customer', or null
```

---

### Function: hasAnyPermission()

```typescript
function hasAnyPermission(functionCode: string): boolean
```

**Description:** Check if user has ANY permission for a function

**Returns:** true if user has at least one action permission

**Usage:**
```typescript
if (hasAnyPermission('PRODUCT_MANAGEMENT')) {
  // User can do something with products
  // (even if limited to just viewing)
}
```

---

### Function: formatPermission()

```typescript
function formatPermission(action: PermissionAction): string
```

**Description:** Convert permission action to display-friendly label

**Parameters:**
- `action`: One of 'can_view', 'can_add', 'can_edit', 'can_delete', 'can_export'

**Returns:** Display string

**Return Mapping:**
```
'can_view'   → 'View'
'can_add'    → 'Create'
'can_edit'   → 'Edit'
'can_delete' → 'Delete'
'can_export' → 'Export'
```

**Usage:**
```typescript
const label = formatPermission('can_view');
// 'View'

// Use in UI:
{#each ['can_view', 'can_add', 'can_edit', 'can_delete', 'can_export'] as action}
  <label>{formatPermission(action)}</label>
{/each}
```

---

### Type: PermissionAction

```typescript
type PermissionAction = 'can_view' | 'can_add' | 'can_edit' | 'can_delete' | 'can_export'
```

---

### Type: UserPermissions

```typescript
interface UserPermissions {
  [functionCode: string]: {
    can_view: boolean;
    can_add: boolean;
    can_edit: boolean;
    can_delete: boolean;
    can_export: boolean;
  };
}
```

---

### Constant: FUNCTION_CODES

**Purpose:** Centralized definition of all system function codes

**Structure:** Object with 80+ function code constants

**Example:**
```typescript
const FUNCTION_CODES = {
  // Administration
  USER_MANAGEMENT: 'USER_MANAGEMENT',
  ROLE_MANAGEMENT: 'ROLE_MANAGEMENT',
  PERMISSION_MANAGEMENT: 'PERMISSION_MANAGEMENT',
  BRANCH_MANAGEMENT: 'BRANCH_MANAGEMENT',
  
  // Master Data
  PRODUCT_MANAGEMENT: 'PRODUCT_MANAGEMENT',
  CATEGORY_MANAGEMENT: 'CATEGORY_MANAGEMENT',
  VENDOR_MANAGEMENT: 'VENDOR_MANAGEMENT',
  
  // Operations
  RECEIVING_MANAGEMENT: 'RECEIVING_MANAGEMENT',
  STOCK_MANAGEMENT: 'STOCK_MANAGEMENT',
  PICKING: 'PICKING',
  
  // Finance
  ORDER_MANAGEMENT: 'ORDER_MANAGEMENT',
  REQUISITION_APPROVAL: 'REQUISITION_APPROVAL',
  BILL_APPROVAL: 'BILL_APPROVAL',
  
  // ... and 60+ more
};
```

**Usage:**
```typescript
// Instead of:
if (hasPermission('USER_MANAGEMENT', 'can_view')) { }

// Use:
import { FUNCTION_CODES } from './permissions';
if (hasPermission(FUNCTION_CODES.USER_MANAGEMENT, 'can_view')) { }
```

---

## Data Flow & Implementation

### 1. User Login Flow

```
User enters credentials
↓
POST /api/auth/login
↓
Backend validates credentials
↓
If valid:
  - Query users table
  - Query users.permissions (JSONB)
  - Query user_roles table (if position-based)
  - Query interface_permissions
  - Query approval_permissions
↓
Return AuthSession with:
  - token (JWT)
  - user object (with all permissions populated)
  - loginMethod
  - loginTime
  - expiresAt
↓
Frontend:
  - Store user object in Svelte store (user.js or persistentAuth.ts)
  - Load interface_permissions to determine accessible UIs
  - Initialize permission checking system
  - Store token in localStorage/sessionStorage
```

---

### 2. Permission Check Flow During User Interaction

```
User clicks button (e.g., "Delete User")
↓
Frontend checks:
  hasPermission('USER_MANAGEMENT', 'can_delete')
↓
hasPermission function executes:
  1. Get current user from store
  2. Check user.permissions['USER_MANAGEMENT']?.can_delete
     - If found → use that value
     - If not found → continue to step 3
  3. Check user.roleType
     - If 'Master Admin' → return true
     - If 'Admin' → return true (for delete: false)
     - Else → return false
↓
If hasPermission returns true:
  - Enable button / Show action
  - User can proceed
↓
If hasPermission returns false:
  - Disable button / Hide action
  - Show permission denied message
↓
On submit (if allowed):
  POST /api/users/[id]  (with delete flag)
↓
Backend verifies:
  - Re-check permission server-side
  - If unauthorized → 403 Forbidden
  - If authorized → Process deletion
  - Log action in user_audit_logs
```

---

### 3. Role Assignment Flow

```
Admin creates new role:
  - POST /api/roles
  - Create user_roles record

Admin defines permissions for role:
  - For each of 80+ functions:
    POST /api/role-permissions
    - role_id: UUID of new role
    - function_id: UUID of function
    - can_view: boolean
    - can_add: boolean
    - can_edit: boolean
    - can_delete: boolean
    - can_export: boolean
↓
Admin assigns role to user:
  - PUT /api/users/[user_id]
  - Update: role_type = 'Position-based'
  - Update: position_id = role's position
↓
When user logs in next:
  - User's permissions loaded from role_permissions table
  - Via: user.position_id → role_permissions.role_id
```

---

### 4. User-Specific Permission Override Flow

```
Master Admin assigns custom permission to user:
  - Current user permissions loaded from users.permissions (JSONB)
  - Toggle specific action for specific function
  - PUT /api/users/[user_id]/permissions
  - Update users.permissions JSONB field
↓
When user next checks permission:
  - hasPermission() finds value in users.permissions
  - Uses that value (overrides role defaults)
  - Specific permission takes precedence
```

---

### 5. Approval Workflow Permission Check

```
User attempts to approve $8000 requisition
↓
System checks:
  1. Query approval_permissions for user_id
  2. Check can_approve_requisitions = true?
  3. Check requisition_amount_limit >= 8000?
↓
If both true:
  - Allow approval
  - Update requisition status
  - Log approval action
↓
If either false:
  - Deny approval
  - Show: "Amount exceeds your approval limit"
  - Show: "Please route to higher authority"
  - Suggest approvers with higher limits
```

---

### 6. Interface Access Control

```
User logs in
↓
Load interface_permissions for user_id
↓
Desktop enabled? → Show desktop interface
Mobile enabled? → Show mobile interface
Customer enabled? → Show customer portal
Cashier enabled? → Show cashier interface
↓
If not enabled:
  - Hide from navigation
  - Block direct URL access
  - Show: "You don't have access to this interface"
```

---

## System Setup Checklist

### Initial Setup

- [ ] **Create app_functions records** (80+ function codes)
  - Command: `scripts/seed-functions.sql`
  - Records: One per function code
  - Fields: function_name, function_code, description, category

- [ ] **Create system user_roles** (MASTER_ADMIN, ADMIN)
  - Master Administrator role
  - Administrator role
  - Mark as `is_system_role = true`

- [ ] **Populate role_permissions**
  - Master Admin: All functions × all permissions = true
  - Admin: All functions × (view/add/edit/export = true, delete = false)
  - Expected records: 86+ per role

- [ ] **Create initial admin user**
  - username: admin
  - role_type: Master Admin
  - Set strong password
  - Test login and permission verification

### Per-User Setup

- [ ] **Create user_roles for custom positions** (Cashier, Picker, etc.)
- [ ] **Define role_permissions for each custom role**
- [ ] **Create user in users table**
- [ ] **Create interface_permissions record** (set accessible UIs)
- [ ] **Create approval_permissions record** (if needed)
- [ ] **Test all permission scenarios**

### Testing Scenarios

```
1. Master Admin
   ✓ Can view all functions
   ✓ Can create/edit/delete/export
   ✓ Access all interfaces

2. Admin
   ✓ Can view all functions
   ✓ Can create/edit/export
   ✗ Cannot delete
   ✓ Access admin interfaces

3. Cashier (Position-based)
   ✓ Can view sales functions
   ✓ Can create orders
   ✗ Cannot delete orders
   ✗ Cannot view finance
   ✓ Access cashier interface only

4. Custom Override
   ✓ Position-based role limits apply
   ✓ Master Admin specific permission override works
   ✓ User permission takes precedence over role

5. Interface Permissions
   ✓ Disabled interfaces not accessible
   ✓ Enabled interfaces fully accessible
   ✓ Mobile users can't access desktop-only features
```

---

## Best Practices

### For Developers

1. **Always use FUNCTION_CODES constant** - Never hardcode function codes
2. **Check permissions before rendering UI** - Use canView(), canCreate(), etc.
3. **Check permissions before API calls** - Use hasPermission() before sending requests
4. **Implement server-side checks** - Never trust client-side permission checks alone
5. **Log all permission-dependent actions** - Record in user_audit_logs
6. **Use specific permission checks** - Don't just check role types

### For Administrators

1. **Create role-based permissions, not user-specific** - Easier to manage at scale
2. **Use role hierarchy** - Master Admin > Admin > Position-based > Customer
3. **Set reasonable approval limits** - Based on position and responsibility
4. **Review permissions quarterly** - Ensure still appropriate for role
5. **Enable only needed interfaces** - Reduce confusion and security risk
6. **Document role definitions** - Store in user_roles.description field

### For Security

1. **Always verify server-side** - Client-side checks are for UX only
2. **Implement rate limiting** - On permission check endpoints
3. **Audit all permission changes** - Log in user_audit_logs with reason
4. **Lock accounts after failed attempts** - Use failed_login_attempts field
5. **Implement token expiration** - users.password_expires_at and session tokens
6. **Regular permission audits** - Check for orphaned permissions
7. **Segregation of duties** - Critical functions require multiple approvers

---

## Common Implementation Patterns

### Pattern 1: Conditional UI Rendering

```svelte
<script>
  import { canView, canCreate, canDelete } from '$lib/utils/permissions';
</script>

{#if canView('USER_MANAGEMENT')}
  <div class="user-list">
    <!-- User list component -->
  </div>
{/if}

{#if canCreate('USER_MANAGEMENT')}
  <button>Create User</button>
{/if}

{#if canDelete('USER_MANAGEMENT')}
  <button>Delete User</button>
{/if}
```

### Pattern 2: Permission-Aware API Integration

```typescript
import { hasPermission } from '$lib/utils/permissions';

async function deleteUser(userId) {
  if (!hasPermission('USER_MANAGEMENT', 'can_delete')) {
    throw new Error('Permission denied: Cannot delete users');
  }
  
  const response = await fetch(`/api/users/${userId}`, {
    method: 'DELETE'
  });
  
  if (response.status === 403) {
    // Server also denied - permission revoked since check
    throw new Error('Permission denied by server');
  }
  
  return response.json();
}
```

### Pattern 3: Role-Based Navigation

```typescript
import { isMasterAdmin, isAdmin, getUserRole } from '$lib/utils/permissions';

function getAvailableMenuItems() {
  const items = [];
  
  // Basic items (everyone)
  items.push({ label: 'Dashboard', path: '/dashboard' });
  items.push({ label: 'My Profile', path: '/profile' });
  
  // Staff items
  if (getUserRole() !== 'Customer') {
    items.push({ label: 'Orders', path: '/orders' });
    items.push({ label: 'Products', path: '/products' });
  }
  
  // Admin items
  if (isAdmin() || isMasterAdmin()) {
    items.push({ label: 'Users', path: '/admin/users' });
    items.push({ label: 'Reports', path: '/admin/reports' });
  }
  
  // Master Admin items
  if (isMasterAdmin()) {
    items.push({ label: 'System Settings', path: '/admin/settings' });
  }
  
  return items;
}
```

### Pattern 4: Approval Workflow

```typescript
import { db } from '$lib/utils/supabase';

async function approveRequisition(requisitionId, approvalAmount) {
  // Check user's approval permissions
  const approver = get(currentUser);
  
  const { data: approvalPerms } = await db
    .from('approval_permissions')
    .select('*')
    .eq('user_id', approver.id)
    .single();
  
  // Check if user can approve requisitions
  if (!approvalPerms?.can_approve_requisitions) {
    throw new Error('You do not have requisition approval permissions');
  }
  
  // Check if amount is within limit
  if (approvalAmount > approvalPerms.requisition_amount_limit) {
    throw new Error(
      `Amount ${approvalAmount} exceeds your limit of ${approvalPerms.requisition_amount_limit}`
    );
  }
  
  // Approve
  await db
    .from('requisitions')
    .update({ status: 'approved', approved_by: approver.id })
    .eq('id', requisitionId);
}
```

---

## Troubleshooting

### Issue: User can't see feature but should be able to

**Check:**
1. Is user.permissions field populated with that function?
2. Does user have the correct role_type?
3. If position-based, does position have role_permissions entries?
4. Is that function in app_functions table?
5. Check user_audit_logs for when permissions changed

**Solution:**
1. Check current permissions: `SELECT permissions FROM users WHERE id = ?`
2. Check role permissions: `SELECT * FROM role_permissions WHERE role_id = ?`
3. Add missing role_permissions: `INSERT INTO role_permissions ...`
4. Or directly set user permissions: `UPDATE users SET permissions = ... WHERE id = ?`

### Issue: Deletion is failing even with can_delete = true

**Check:**
1. Is Admin being checked? (Admins have delete disabled by default)
2. Is server-side check happening? (Client check might pass, server fails)
3. Is user.roleType = 'Admin'? (Falls back to roleType if permission not explicit)

**Solution:**
1. Set explicit permission: `UPDATE users SET permissions = ... WHERE id = ?`
2. Or promote to Master Admin if needed
3. Verify server-side permission check is using same logic

### Issue: Role permissions not applying to users

**Check:**
1. Does user have role_type set? (Not null)
2. Does user have position_id set? (For position-based roles)
3. Do role_permissions entries exist? (Query role_permissions table)
4. Are function_ids correct? (Foreign key to app_functions)

**Solution:**
1. Ensure user.role_type is set correctly
2. Ensure user.position_id links to correct position
3. Create role_permissions entries: `INSERT INTO role_permissions ...`
4. Test with simple function: `SELECT * FROM role_permissions WHERE role_id = ? LIMIT 5`

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Current | Complete permission system documentation |

---

## Support & Contact

For questions about the permission system:
- Check this documentation file
- Review permissions.ts source code
- Examine DATABASE_SCHEMA.md for table details
- Check user_audit_logs for recent changes

---

**Document Version:** 1.0  
**Last Updated:** 2024  
**Maintained By:** System Administration  
**Status:** Complete & Production-Ready
