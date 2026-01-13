# Petty Cash Payments Feature - Implementation Guide

## Overview
Adds ability to make Vendor, Expense, and User payments directly from Petty Cash box with automatic denomination tracking and synchronization with the Denomination component.

## Requirements

### UI Components
- **Three Payment Buttons** (under the cards in PettyCash.svelte):
  1. Vendor Payment
  2. Expense Payment  
  3. User Payment

### Functionality
1. **Modal Forms**: Open similar modals to Denomination component for each payment type
2. **Search Integration**: Reuse vendor, expense, and user search from Denomination component
3. **Remarks**: Auto-populate with "Paid from petty cash"
4. **Date/Time**: Capture transaction timestamp automatically
5. **Denomination**: Allow optional denomination breakdown for payment
6. **Deduction**: Remove paid amount from petty cash counts and reduce grand_total
7. **Display**: Show in two places:
   - **Denomination Component**: Appear on "Paid" section (same as other payments)
   - **Petty Cash Component**: Show transaction history with Delete button

### Database Integration
- **Table**: Same table used by Denomination component for payments (likely `denomination_transactions`)
- **Key Fields**:
  - Type: 'vendor' | 'expenses' | 'user'
  - Section: 'paid'
  - Amount: Payment amount
  - Remarks: "Paid from petty cash"
  - Apply_denomination: true/false
  - Denominations (if applicable): {...}
  - Created_at: Timestamp
  - Record_type: 'petty_cash_box'
  - Branch_id: Current branch
  - User_id: Current user

### Data Flow
1. User clicks payment button → Modal opens
2. User selects vendor/expense/user
3. User enters amount and optional denominations
4. User clicks save
5. System:
   - Creates transaction record
   - Deducts from petty cash counts
   - Updates petty cash grand_total
   - Updates denomination_records record
   - Shows in both components
6. User can delete from petty cash table → removes transaction and restores petty cash balance

### Petty Cash Transaction Table
Display format:
| Type | Vendor/Expense/User | Amount | Remarks | Date | Action |
|------|-----|--------|---------|------|--------|
| Vendor | Name | 500.00 | Paid from petty cash | 2026-01-13 14:30 | Delete |

## Implementation Approach: Option A

### Storage Strategy
- **Single Table**: `denomination_transactions`
- **Identifier Flag**: `paid_from_petty_cash: true` in `entity_data` JSONB
- **Automatic Remarks**: "Paid from petty cash"
- **Section**: Always 'paid'
- **Types**: 'vendor' | 'expenses' | 'user'

### Data Structure
```json
{
  "id": "uuid",
  "branch_id": 3,
  "section": "paid",
  "transaction_type": "vendor|expenses|user",
  "amount": 500.00,
  "remarks": "Paid from petty cash",
  "apply_denomination": true/false,
  "denomination_details": {...},
  "entity_data": {
    "paid_from_petty_cash": true,
    "vendor_id": "...",
    "vendor_name": "...",
    "expense_id": "...",
    "user_id": "...",
    ...
  },
  "created_by": "user_id",
  "created_at": "timestamp"
}
```

### Payment Flow
1. User clicks Vendor/Expense/User Payment button
2. Modal opens (reuses search from Denomination component)
3. User selects entity, enters amount, optional denominations
4. System saves to `denomination_transactions` with `paid_from_petty_cash: true`
5. Deducts from petty cash `counts` column
6. Updates petty cash `grand_total`
7. Updates petty cash `updated_at`

### Display
- **Denomination Component**: Automatically shows on "Paid" section (queries denomination_transactions)
- **Petty Cash Component**: Shows transaction history table with Delete button

### Delete Flow
1. User clicks Delete in petty cash transaction table
2. Remove from `denomination_transactions`
3. Restore denomination counts to petty cash
4. Restore grand_total
5. Update petty cash `updated_at`

### Synchronization
- Use realtime subscriptions so both components auto-update
- No separate petty_cash_operation tracking needed for payments (only for transfers)

## Integration Points
- **Denomination Component**: Queries `denomination_transactions` with section='paid'
- **Search Functions**: Reuse vendor/expense/user search from Denomination component
- **Transaction Table**: Same `denomination_transactions` schema
- **Realtime**: Subscribe to denomination_transactions changes

## Implementation Steps
1. Add three payment buttons under cards in PettyCash.svelte
2. Create payment modal functions (vendor, expense, user)
3. Load vendor/expense/user data (reuse Denomination functions if possible)
4. Implement savePaymentTransaction() function
5. Add petty cash transaction history table with delete
6. Setup realtime listener for denomination_transactions
7. Test synchronization with Denomination component

## Notes
- All payments marked as "Paid" section
- All have "Paid from petty cash" in remarks
- Optional denomination breakdown (similar to Denomination component)
- Full audit trail with timestamps
- Reversible via delete function
- Single source of truth in denomination_transactions
