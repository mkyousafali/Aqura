# Amount Adjustment Feature Implementation
**Date:** October 29, 2025
**Feature:** Edit scheduled payment amounts with Discount, GRR, and PRI tracking

## Overview
Added functionality to adjust vendor payment scheduled amounts in the Month Details view with proper tracking of:
- Discount deductions
- GRR (Goods Receipt Return) deductions with reference numbers
- PRI (Purchase Return Invoice) deductions with reference numbers

## Files Modified

### 1. Migration File
**File:** `supabase/migrations/add_amount_adjustment_columns.sql`
- Added columns for tracking discount, GRR, and PRI adjustments
- Added reference number fields for GRR and PRI
- Added notes fields for each adjustment type
- Added metadata tracking (last_adjustment_date, last_adjusted_by, adjustment_history)
- Created automatic trigger to recalculate `final_bill_amount` when adjustments change
- Added constraints to ensure amounts are positive and total deductions don't exceed bill amount
- Created indexes for faster queries on adjustment-related fields

**New Columns:**
- `discount_amount` - Discount amount deducted
- `discount_notes` - Notes for discount
- `grr_amount` - Goods Receipt Return amount
- `grr_reference_number` - Reference number for GRR (required if grr_amount > 0)
- `grr_notes` - Notes for GRR
- `pri_amount` - Purchase Return Invoice amount
- `pri_reference_number` - Reference number for PRI (required if pri_amount > 0)
- `pri_notes` - Notes for PRI
- `last_adjustment_date` - Timestamp of last adjustment
- `last_adjusted_by` - User ID who made the adjustment
- `adjustment_history` - JSONB array storing all adjustment history

### 2. MonthDetails Component
**File:** `frontend/src/lib/components/admin/vendor/MonthDetails.svelte`

#### Added State Variables:
```javascript
let showEditAmountModal = false;
let editingAmountPayment = null;
let editAmountForm = {
    discountAmount: 0,
    discountNotes: '',
    grrAmount: 0,
    grrReferenceNumber: '',
    grrNotes: '',
    priAmount: 0,
    priReferenceNumber: '',
    priNotes: ''
};
```

#### Added Functions:
- `openEditAmountModal(payment)` - Opens the edit amount modal
- `closeEditAmountModal()` - Closes the modal and resets form
- `calculateNewFinalAmount()` - Calculates new final amount based on deductions
- `saveAmountAdjustment()` - Saves the adjustment to database with validation

#### UI Changes:
- Added 💰 "Edit Amount" button in the Actions column for unpaid payments
- Created comprehensive edit modal with:
  - Payment information display
  - Discount input field with notes
  - GRR amount and reference number inputs with notes
  - PRI amount and reference number inputs with notes
  - Real-time calculation summary showing new final amount
  - Validation messages for invalid inputs

### 3. Script Update
**File:** `scripts/check-vendor-payment-schedule.cjs`
- Updated Supabase URL and service role key to match current environment

## Features

### Edit Amount Modal
1. **Payment Information Section**
   - Displays vendor name, bill date, original bill amount, current final amount

2. **Discount Section**
   - Amount input field
   - Optional notes textarea

3. **GRR Section**
   - Amount input field
   - Reference number field (required if amount > 0)
   - Optional notes textarea

4. **PRI Section**
   - Amount input field
   - Reference number field (required if amount > 0)
   - Optional notes textarea

5. **Calculation Summary**
   - Shows original bill amount
   - Lists all deductions
   - Displays new final amount
   - Error message if total deductions exceed bill amount

### Validation Rules
- All amounts must be non-negative
- Total deductions cannot exceed bill amount
- GRR reference number required if GRR amount > 0
- PRI reference number required if PRI amount > 0
- Save button disabled if validation fails

### Database Automation
- Trigger automatically updates `final_bill_amount` when any adjustment columns change
- Adjustment history is stored in JSONB format for audit trail
- Tracks who made the adjustment and when

## Business Logic
The `final_bill_amount` is automatically calculated as:
```
final_bill_amount = bill_amount - discount_amount - grr_amount - pri_amount
```

This calculation happens automatically via database trigger whenever:
- A new payment is inserted
- The bill_amount changes
- Any adjustment amount (discount, GRR, PRI) changes

## Usage
1. Navigate to Month Details view
2. Find the unpaid payment you want to adjust
3. Click the 💰 button in the Actions column
4. Enter adjustment amounts and required reference numbers
5. Review the calculation summary
6. Click "Save Adjustment"

## Migration Deployment
To apply the migration:
```sql
-- Run in Supabase SQL Editor
-- File: supabase/migrations/add_amount_adjustment_columns.sql
```

## History Tracking
Every adjustment is recorded in the `adjustment_history` JSONB column with:
- Timestamp
- User ID and name
- Previous final amount
- New final amount
- All adjustment details (discount, GRR, PRI with references)

## Future Enhancements
- View adjustment history in a timeline
- Export adjustment reports
- Bulk adjustment operations
- Attachment upload for GRR/PRI documents
- Email notifications for adjustments
