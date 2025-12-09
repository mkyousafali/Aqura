# StartReceiving.svelte - Complete Process Reference

## Overview
`StartReceiving.svelte` is a comprehensive 4-step receiving management system for handling vendor goods intake, documentation, and staff assignment. It includes vendor management, bill processing, VAT verification, return handling, and clearance certification.

**File Location:** `frontend/src/lib/components/desktop-interface/master/operations/receiving/StartReceiving.svelte`
**Total Lines:** 8,313

---

## 4-Step Process Flow

### Step 1: Select Branch
- User selects a branch from available branches
- Current logged-in user is auto-assigned as the receiving user
- Option to set as default branch
- Loads all branch users filtered by their positions

### Step 2: Select Vendor
- Search and select vendor from list
- Vendor search filters by:
  - ERP vendor ID
  - Vendor name
  - Salesman name
  - Salesman contact
  - Supervisor contact
  - Vendor location
- Updates vendor if missing critical information (salesman name, salesman contact, VAT number)

### Step 3: Bill Information
- Enter bill date and bill amount
- Capture VAT information from bill
- Handle payment method and credit period
- Process returns for different categories:
  - Expired items
  - Near-expiry items
  - Over-stock items
  - Damaged items
- Each return type includes ERP document details

### Step 4: Finalization - Employee Assignment
- Assign required staff members (ALL REQUIRED except Night Supervisors):
  - **Branch Manager** (required, single selection)
  - **Shelf Stocker** (required, single selection)
  - **Accountant** (required, single selection) ✓
  - **Purchasing Manager** (required, single selection)
  - **Inventory Manager** (required, single selection)
  - **Night Supervisors** (optional, multiple selection - minimum 1)
  - **Warehouse Handler** (required, single selection)
- View clearance certificate
- Save receiving record

---

## Key State Variables

### Step Navigation
```typescript
let steps = ['Select Branch', 'Select Vendor', 'Bill Information', 'Finalization'];
let currentStep = 0;
let allRequiredUsersSelected = false;
```

### Branch Selection
```typescript
let branches = [];
let selectedBranch = '';
let selectedBranchName = '';
let receivingUser = null; // Current logged-in user (auto-selected)
let setAsDefaultBranch = false;
```

### Vendor Selection
```typescript
let vendors = [];
let filteredVendors = [];
let searchQuery = '';
let selectedVendor = null;
let vendorLoading = false;
```

### Staff Assignment (Multiple Types)
Each staff type has similar state structure:
```typescript
let [role] = [];              // All users from branch
let actual[Role]s = [];       // Only users with specific position
let filtered[Role]s = [];     // Filtered search results
let selected[Role] = null;    // Selected user(s)
let [role]Loading = false;    // Loading state
let [role]SearchQuery = '';   // Search input
let showAllUsersFor[Role] = false; // Fallback flag
```

**Staff Types:**
- Branch Managers
- Shelf Stockers
- Accountants
- Purchasing Managers
- Inventory Managers
- Night Supervisors (multiple selection)
- Warehouse Handlers

### Bill Information
```typescript
let currentDateTime = '';
let billDate = '';
let billAmount = '';
let billNumber = '';
let paymentMethod = '';
let creditPeriod = '';
let bankName = '';
let iban = '';
let dueDate = ''; // Calculated from bill date + credit period
```

### VAT Verification
```typescript
let vendorVatNumber = '';      // From vendor record
let billVatNumber = '';        // From bill entry
let vatMismatchReason = '';    // Reason for mismatch
```

### Returns Processing
```typescript
let returns = {
  expired: {
    hasReturn: 'no',
    amount: '',
    erpDocumentType: '',
    erpDocumentNumber: '',
    vendorDocumentNumber: ''
  },
  nearExpiry: { ... },
  overStock: { ... },
  damage: { ... }
};
```

### Column Visibility
```typescript
let showColumnSelector = false;
let visibleColumns = {
  erp_vendor_id: true,
  vendor_name: true,
  salesman_name: true,
  salesman_contact: false,
  supervisor_name: false,
  supervisor_contact: false,
  vendor_contact: true,
  payment_method: true,
  credit_period: false,
  bank_name: false,
  iban: false,
  last_visit: false,
  place: true,
  location: false,
  categories: true,
  delivery_modes: true,
  return_expired: false,
  return_near_expiry: false,
  return_over_stock: false,
  return_damage: false,
  no_return: false,
  vat_status: false,
  vat_number: false,
  status: true,
  actions: true
};
```

### Clearance & Certification
```typescript
let showCertification = false;
let showCertificateManager = false;
let currentReceivingRecord = null;
let savedReceivingId = null;
```

---

## Core Functions

### Data Loading Functions

#### `loadBranches()`
- Loads all branches from database
- Sets `branches` array
- Filters by user permissions

#### `loadVendors()`
- Loads all vendors from database
- Filters by branch (if applicable)
- Populates `vendors` array
- Handles loading and error states

#### `loadBranchUsers(branchId)`
- Consolidated function to load all users in a branch
- Filters users by their positions:
  - Branch Manager
  - Shelf Stocker
  - Accountant
  - Purchasing Manager
  - Inventory Manager
  - Night Supervisor
  - Warehouse Handler / Stock Handler
- Stores both full list and filtered lists

#### Position-Specific Load Functions
- `loadPurchasingManagersForSelection()`
- `loadInventoryManagersForSelection()`
- `loadNightSupervisorsForSelection()`
- `loadWarehouseHandlersForSelection()`
- `loadShelfStockersForSelection()`
- `loadAccountantsForSelection()`

### Search & Selection Functions

#### Branch Manager
- `handleBranchUserSearch()` - Filter branch managers by search query
- `selectBranchManager(user)` - Select a branch manager
- `showAllUsersForSelection()` - Show all users when no matches found

#### Shelf Stocker
- `handleShelfStockerSearch()`
- `selectShelfStocker(user)`
- `removeShelfStocker()`
- `showAllUsersForShelfStockerSelection()`

#### Accountant
- `handleAccountantSearch()`
- `selectAccountant(user)`
- `showAllUsersForAccountantSelection()`

#### Purchasing Manager
- `handlePurchasingManagerSearch()`
- `selectPurchasingManager(user)`
- `showAllUsersForPurchasingManagerSelection()`

#### Inventory Manager
- `handleInventoryManagerSearch()`
- `selectInventoryManager(user)`
- `showAllUsersForInventoryManagerSelection()`

#### Night Supervisor (Multiple Selection)
- `handleNightSupervisorSearch()`
- `selectNightSupervisor(user)` - Adds to array
- `removeNightSupervisor(userId)` - Removes from array
- `showAllUsersForNightSupervisorSelection()`

#### Warehouse Handler
- `handleWarehouseHandlerSearch()`
- `selectWarehouseHandler(user)`
- `removeWarehouseHandler()`
- `showAllUsersForWarehouseHandlerSelection()`

#### Vendor
- `handleVendorSearch()` - Filter vendors by:
  - ERP vendor ID
  - Vendor name
  - Salesman name
  - Salesman contact
  - Supervisor contact
  - Location
- `selectVendor(vendor)` - Check for missing info and show update popup if needed

### Vendor Update Function

#### `updateVendorInformation()`
- Updates vendor record with:
  - Salesman name
  - Salesman contact
  - VAT number
- Shows confirmation popup for missing information
- Validates before saving

#### `handleVendorUpdate()`
- Processes vendor update
- Shows error/success messages
- Closes popup on success

### Step Navigation Functions

#### `confirmBranchSelection()`
- Validates branch selection
- Moves to Step 2 (Select Vendor)
- Loads branch users

#### `changeBranch()`
- Resets branch selection
- Goes back to branch selector

### Utility Functions

#### `maskVatNumber(vatNumber)`
- Shows only last 4 digits
- Masks remaining digits with asterisks
- Example: `"123456789"` → `"*****6789"`

### Data Saving Functions

#### `saveReceivingRecord()`
- Saves complete receiving transaction to database
- Captures:
  - Branch ID
  - Vendor ID
  - Bill information (date, amount, number)
  - Payment details
  - Staff assignments
  - Return information
  - VAT verification
  - Clearance details
- Returns `savedReceivingId` for certification

---

## Component Imports

```typescript
import StepIndicator from './StepIndicator.svelte';
import ClearanceCertificateManager from './ClearanceCertificateManager.svelte';
import EditVendor from '$lib/components/desktop-interface/master/vendor/EditVendor.svelte';
import { currentUser } from '$lib/utils/persistentAuth';
import { supabase } from '$lib/utils/supabase';
import { windowManager } from '$lib/stores/windowManager';
import { openWindow } from '$lib/utils/windowManagerUtils';
import { onMount } from 'svelte';
```

---

## Database Operations

### Tables Used
- `branches` - Branch information
- `vendors` - Vendor details
- `employees` - Staff/user information
- `employee_positions` - User position assignments
- `receiving_records` - Main receiving transaction records
- `clearance_certificates` - Receiving clearance documents

### Data Validation
- VAT number verification (vendor vs. bill)
- Required field validation before progression
- Staff member position verification

---

## UI Components & Features

### Step Indicator
- Visual representation of current step
- Navigation between steps
- Progress tracking

### Search Functionality
- Real-time filtering
- Case-insensitive matching
- Multiple field search for vendors

### Staff Selection
- Autocomplete-style dropdown
- Multiple selection support (Night Supervisors)
- Single selection for other roles
- Fallback to show all users when no matches

### Vendor Management
- Quick update popup for missing information
- VAT number masking
- Payment method and credit period tracking

### Returns Processing
- Category-based return tracking (expired, near-expiry, over-stock, damage)
- ERP document reference capture
- Individual return amounts

### Column Visibility Toggle
- 22 available columns
- User can customize visible columns
- Persistent visibility settings

---

## Error Handling

- Loading states for all async operations
- Error messages displayed to user
- Fallback options when users not found
- Validation before saving

---

## Key Features

1. **Multi-step wizard interface** for organized data entry
2. **Real-time search** across branches, vendors, and staff
3. **Automatic user assignment** (current logged-in user as receiver)
4. **VAT verification** with mismatch handling
5. **Return categorization** with ERP document tracking
6. **Staff role-based filtering** ensuring correct person assigned
7. **Flexible column visibility** for custom views
8. **Clearance certification** for audit trail
9. **Vendor validation** with critical information checks
10. **Payment method tracking** for financial reconciliation

---

## Technical Stack

- **Language:** TypeScript (Svelte)
- **Database:** Supabase (PostgreSQL)
- **State Management:** Svelte stores
- **Styling:** CSS (within component)
- **Window Management:** Custom window manager store

---

## Performance Considerations

- **Consolidated user loading:** Single database query for all branch users
- **Filtered arrays:** Separate arrays for search vs. full data
- **Conditional rendering:** Only visible content is rendered
- **Lazy loading:** Data loaded on demand per step
- **Column visibility management:** Reduces rendered DOM elements

