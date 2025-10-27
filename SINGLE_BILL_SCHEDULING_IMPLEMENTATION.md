# Single Bill Scheduling Implementation

## Overview
This document describes the implementation of the Single Bill Scheduling feature for the Aqura expense management system.

## Database Schema

### Migration Files Created

#### 1. `050_create_expense_scheduler_table.sql`
Creates the main `expense_scheduler` table with the following key fields:

**Step 1 Fields (Branch & Category):**
- `branch_id` - Foreign key to branches table
- `branch_name` - Cached branch name
- `expense_category_id` - Foreign key to expense_sub_categories
- `expense_category_name_en` - English category name
- `expense_category_name_ar` - Arabic category name

**Step 2 Fields (Request & User):**
- `requisition_id` - Optional link to expense_requisitions
- `requisition_number` - Cached requisition number
- `co_user_id` - Foreign key to users table (mandatory)
- `co_user_name` - Cached username

**Step 3 Fields (Bill Details):**
- `bill_type` - Enum: 'vat_applicable', 'no_vat', 'no_bill'
- `bill_number` - Bill reference number
- `bill_date` - Date on the bill
- `payment_method` - Payment type: 'advance_cash', 'check', 'bank_transfer', 'credit_card', 'cash'
- `due_date` - Auto-calculated based on payment method
- `credit_period` - Number of days for credit
- `amount` - Bill amount in SAR
- `bill_file_url` - Storage URL for uploaded bill

**Payment Tracking:**
- `is_paid` - Boolean flag for payment status
- `paid_date` - Timestamp when payment was made

**Status & Audit:**
- `status` - Current status: 'pending', 'approved', 'rejected', 'paid'
- `created_by`, `created_at`, `updated_by`, `updated_at` - Audit fields

**Features:**
- RLS (Row Level Security) enabled
- Comprehensive indexes for query performance
- Foreign key constraints for data integrity
- Auto-updated `updated_at` trigger

#### 2. `051_create_expense_scheduler_storage.sql`
Creates storage bucket for bill files:

**Bucket Name:** `expense-scheduler-bills`

**Features:**
- 10MB file size limit
- Supports: JPEG, PNG, GIF, WebP images and PDF files
- Private bucket with RLS policies
- Authenticated users can upload, read, update, and delete

## UI Components

### 1. SingleBillScheduling.svelte
Main component implementing the 3-step wizard:

**Step 1: Branch & Category Selection**
- Branch dropdown (mandatory)
- Searchable category table with English and Arabic names
- Radio selection for single category

**Step 2: Request & User Selection**
- Optional: Link to approved expense requisitions (searchable table)
- Mandatory: C/O user selection from branch-specific and global users
- Search functionality for both tables

**Step 3: Bill Details & Payment**
- Bill type selection (VAT-applicable / No-VAT / No bill)
- Conditional fields:
  - Bill number (mandatory if bill selected)
  - Bill date (mandatory if bill selected)
  - File upload (mandatory if bill selected)
- Payment method dropdown with credit period info
- Auto-calculated due date based on bill date and payment method
- Amount input with large display
- Description/notes textarea

**Payment Methods:**
| Method | Credit Days |
|--------|-------------|
| Advance Cash | 0 |
| Cash | 0 |
| Bank Transfer | 7 |
| Credit Card | 15 |
| Check | 30 |

**Features:**
- Step-by-step validation
- Progress indicator
- File upload with type and size validation
- Auto-calculation of due dates
- Success feedback with auto-reset
- Responsive design
- Accessibility compliant

### 2. Scheduler.svelte (Updated)
Home screen for scheduling options:

**Features:**
- Card-based navigation
- View switching between home and Single Bill Scheduling
- Back navigation button
- Placeholders for upcoming features:
  - Multiple Bill Scheduling
  - Recurring Bill Scheduling

## Payment Method Credit Periods

The due date is automatically calculated based on:
```javascript
Due Date = Bill Date + Credit Period Days
```

Credit periods:
- **Advance Cash / Cash**: 0 days (immediate)
- **Bank Transfer**: 7 days
- **Credit Card**: 15 days
- **Check**: 30 days

## File Upload Specifications

**Accepted File Types:**
- Images: JPEG, JPG, PNG, GIF, WebP
- Documents: PDF

**File Size Limit:** 10MB

**Storage Path:** `{branch_id}/{timestamp}_{filename}`

## Validation Rules

### Step 1
- Branch selection is mandatory
- Expense category selection is mandatory

### Step 2
- C/O user selection is mandatory
- Request linking is optional

### Step 3
- Amount must be greater than 0
- If bill type is VAT-applicable or No-VAT:
  - Bill number is mandatory
  - Bill file upload is mandatory
  - Bill date is required for due date calculation

## API Integration

### Tables Used:
1. `branches` - Branch data
2. `expense_sub_categories` - Expense categories
3. `expense_requisitions` - Approved requests (filtered by branch)
4. `users` - User data (filtered by branch + global users)
5. `expense_scheduler` - New table for scheduled bills

### Storage:
- Bucket: `expense-scheduler-bills`
- Upload method: `supabaseAdmin.storage.from().upload()`
- Public URL retrieval for stored files

## Security

**Row Level Security (RLS):**
- Authenticated users can read all scheduler entries
- Authenticated users can create new entries
- Authenticated users can update entries
- Service role has full access

**Storage Security:**
- Private bucket (not publicly accessible)
- Authenticated users only
- RLS policies on storage.objects

## Future Enhancements

**Planned Features:**
1. Multiple Bill Scheduling - Batch schedule multiple bills
2. Recurring Bill Scheduling - Set up automatic recurring schedules
3. Payment approval workflow
4. Payment status tracking
5. Notification system for due dates
6. Reporting and analytics

## Usage

1. Navigate to Finance > Scheduler
2. Click "Single Bill Scheduling"
3. Complete the 3-step wizard:
   - Select branch and category
   - Select c/o user (optionally link to request)
   - Enter bill details and amount
4. Click "Save Bill Schedule"
5. Success message displays with scheduler ID
6. Form auto-resets after 2 seconds

## Technical Notes

- Component uses Svelte stores for current user
- Uses `supabaseAdmin` for database operations
- Implements client-side validation before saving
- File upload happens before database insert
- Auto-calculation of due dates using reactive statements
- Comprehensive error handling with user feedback

## Migration Deployment

To deploy the migrations:

```bash
# Make sure Supabase CLI is installed and configured
npx supabase db push

# Or apply migrations individually
npx supabase migration up
```

## Testing Checklist

- [ ] Branch selection loads all active branches
- [ ] Category table displays and is searchable
- [ ] Category selection persists through steps
- [ ] Request table shows only approved requests for selected branch
- [ ] User table shows branch-specific and global users
- [ ] Bill type changes show/hide conditional fields
- [ ] File upload validates type and size
- [ ] Due date auto-calculates correctly for each payment method
- [ ] Amount validation works (positive numbers only)
- [ ] Save operation creates database record
- [ ] File uploads to storage successfully
- [ ] Success message displays after save
- [ ] Form resets properly
- [ ] Back navigation works correctly
- [ ] RLS policies allow proper access

## Dependencies

**Frontend:**
- Svelte
- Supabase client
- html2canvas (inherited from existing components)

**Database:**
- PostgreSQL (via Supabase)
- Storage bucket support

## Contact & Support

For questions or issues with this implementation, refer to the main project documentation or contact the development team.
