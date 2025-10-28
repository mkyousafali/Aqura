# Expense Due Date Fix - 2025-01-29

## Issue
Expense scheduler records were showing due dates as `01/01/1970` in the Unpaid Scheduled Payments view. This was happening because:

1. When bills had `bill_type = 'no_bill'`, no bill date was entered
2. The `calculateDueDate()` function required both `billDate` and `paymentMethod` to calculate due date
3. Without a bill date, due date was never calculated and remained as empty string `''`
4. Empty string was saved as `null` in the database
5. When displaying, `new Date(null)` resulted in the Unix epoch date (01/01/1970)

## Root Cause
The due date calculation logic in `SingleBillScheduling.svelte` was:

```javascript
function calculateDueDate() {
    if (!billDate || !paymentMethod) return;  // ❌ Problem: Requires billDate
    // ... calculate based on billDate
}
```

This meant that for "No Bill" transactions, no due date was ever calculated.

## Solution

### 1. Fixed Due Date Calculation Logic
**File:** `frontend/src/lib/components/admin/finance/SingleBillScheduling.svelte`

Updated `calculateDueDate()` to:
- Use bill date if available
- Fallback to current date if no bill date
- Always calculate due date when payment method is selected

```javascript
function calculateDueDate() {
    if (!paymentMethod) return;
    
    const selectedMethod = paymentMethods.find((m) => m.value === paymentMethod);
    if (!selectedMethod) return;
    
    const creditDays = selectedMethod.creditDays;
    // Use billDate if available, otherwise use current date
    const baseDate = billDate ? new Date(billDate) : new Date();
    baseDate.setDate(baseDate.getDate() + creditDays);
    
    dueDate = baseDate.toISOString().split('T')[0];
}
```

### 2. Enhanced Date Display with Validation
Added proper null/invalid date handling in display components:

**Files Updated:**
- `frontend/src/lib/components/admin/vendor/UnpaidScheduledDetails.svelte`
- `frontend/src/lib/components/admin/vendor/ScheduledPayments.svelte`
- `frontend/src/lib/components/admin/vendor/MonthDetails.svelte`

Added safe date formatting:
```javascript
function formatDueDate(dateString) {
    if (!dateString) return 'N/A';
    try {
        const date = new Date(dateString);
        // Check if date is valid
        if (isNaN(date.getTime())) return 'N/A';
        return date.toLocaleDateString('en-GB');
    } catch (error) {
        return 'N/A';
    }
}
```

### 3. Database Migration to Fix Existing Records
**File:** `supabase/migrations/069_fix_null_expense_scheduler_due_dates.sql`

Created migration to update existing null due_date values:
- Priority 1: Use `bill_date + credit_period` if bill_date exists
- Priority 2: Use `created_at + credit_period` as fallback
- Ensures all records have valid due dates

## Files Modified

1. **frontend/src/lib/components/admin/finance/SingleBillScheduling.svelte**
   - Updated `calculateDueDate()` function
   - Added reactive statement to recalculate on payment method change

2. **frontend/src/lib/components/admin/vendor/UnpaidScheduledDetails.svelte**
   - Added `formatDueDate()` helper function
   - Updated display to use safe date formatting
   - Added null check in `calculateDaysOverdue()`

3. **frontend/src/lib/components/admin/vendor/ScheduledPayments.svelte**
   - Enhanced `formatDate()` with validation

4. **frontend/src/lib/components/admin/vendor/MonthDetails.svelte**
   - Enhanced `formatDate()` with validation

5. **supabase/migrations/069_fix_null_expense_scheduler_due_dates.sql**
   - New migration to fix existing data

## Testing Checklist

- [ ] Create new expense schedule with "No Bill" type
- [ ] Verify due date is calculated based on current date + credit days
- [ ] Create new expense schedule with bill (VAT or No-VAT)
- [ ] Verify due date is calculated based on bill date + credit days
- [ ] Run migration 069 on database
- [ ] Verify all existing records now have valid due dates
- [ ] Check Unpaid Scheduled Payments view - should show proper dates
- [ ] Check Scheduled Payments calendar view
- [ ] Check Month Details view
- [ ] Verify overdue calculations work correctly

## Migration Instructions

1. **Apply the migration:**
   ```bash
   # If using Supabase CLI
   supabase db push
   
   # Or manually run the SQL in Supabase dashboard
   ```

2. **Verify the fix:**
   - Open Unpaid Scheduled Payments Details
   - Check that expense records show proper dates (not 01/01/1970)
   - Verify days overdue calculations are correct

## Prevention
- Due date is now always calculated when payment method is selected
- All date display functions now validate dates before formatting
- Database ensures due_date is set for all new records
