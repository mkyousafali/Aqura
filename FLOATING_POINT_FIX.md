# Floating-Point Precision Issue - Vendor Payment Deductions

## Issue Summary

**Date:** November 4, 2025  
**Component:** `MonthDetails.svelte` - Edit Amount Modal  
**Database Table:** `vendor_payment_schedule`  
**Constraint:** `check_total_deductions_valid`

### Problem Description

When attempting to deduct **11837.30** from **22401.25**, the update fails with:

```
Failed to update amount: new row for relation "vendor_payment_schedule" 
violates check constraint "check_total_deductions_valid"
```

However, deducting **11000.37** from the same amount works perfectly.

## Root Cause Analysis

### The Constraint

The database has a CHECK constraint that validates:

```sql
final_bill_amount = bill_amount - (discount_amount + grr_amount + pri_amount)
```

This constraint performs an **exact equality check** using the `=` operator with PostgreSQL's NUMERIC type.

### Floating-Point Precision Issue

JavaScript uses IEEE 754 floating-point arithmetic, which cannot represent all decimal numbers exactly in binary. PostgreSQL uses NUMERIC/DECIMAL for exact decimal arithmetic.

**The Problem:**
```javascript
// JavaScript calculation
22401.25 - 11837.30 = 10563.95000000000072759576
//                           ^^^^^^^^^^^^^^^^
//                           Floating-point error

// PostgreSQL NUMERIC calculation  
22401.25::numeric - 11837.30::numeric = 10563.95 (exact)
```

Even when we round or use toFixed(), JavaScript still stores the value with floating-point representation:
```javascript
parseFloat("10563.95") = 10563.95000000000072759576 (internal representation)
```

When this is sent to PostgreSQL, it gets compared against the exact NUMERIC calculation and fails the constraint check.

## The Solution

### Cent-Based Integer Arithmetic + toFixed()

**Approach:**
1. Convert all amounts to cents (multiply by 100)
2. Perform integer arithmetic (which is exact)
3. Divide by 100 and immediately convert to fixed decimal string
4. Parse the string to send to database

**Code Fix:**

**File:** `d:\Aqura\frontend\src\lib\components\admin\vendor\MonthDetails.svelte`  
**Function:** `saveAmountAdjustment()`  
**Line:** ~1367

```javascript
// Calculate in cents (integer arithmetic - EXACT)
const billCents = Math.round(editingAmountPayment.bill_amount * 100);
const discountCents = Math.round(discountAmount * 100);
const grrCents = Math.round(grrAmount * 100);
const priCents = Math.round(priAmount * 100);
const finalCents = billCents - discountCents - grrCents - priCents;

// Convert to decimal string with exactly 2 places
// This creates an exact representation that PostgreSQL can parse as NUMERIC
const finalAmountStr = (finalCents / 100).toFixed(2);

// Send to database
const { error } = await supabase
  .from('vendor_payment_schedule')
  .update({
    final_bill_amount: parseFloat(finalAmountStr), // Parse from exact string
    discount_amount: discountAmount,
    grr_amount: grrAmount,
    pri_amount: priAmount,
    // ...
  })
```

### Why This Works

1. **Integer arithmetic (cents):** `2240125 - 1183730 = 1056395` (exact, no floating-point error)
2. **Division by 100:** `1056395 / 100 = 10563.95` (still has float representation issue)
3. **toFixed(2):** Converts to string `"10563.95"` (exact decimal representation)
4. **parseFloat():** Converts back to number, but from an exact decimal string
5. **PostgreSQL:** Receives the value and can convert it cleanly to NUMERIC without mismatch

The key is that `.toFixed(2)` creates a **string representation** that, when parsed, aligns better with PostgreSQL's NUMERIC type expectations.

## Testing

### Verification

The fix has been applied and tested with multiple problematic values:
- 11837.30 ✅ NOW WORKS
- 7777.77 ✅ WORKS
- 5000.01 ✅ WORKS
- 12345.67 ✅ WORKS

## Prevention

### Best Practices for Monetary Values

1. **Always use cent-based arithmetic for calculations:**
   ```javascript
   const calculateFinal = (bill, deductions) => {
     const billCents = Math.round(bill * 100);
     const deductionCents = Math.round(deductions * 100);
     const finalCents = billCents - deductionCents;
     return parseFloat((finalCents / 100).toFixed(2));
   };
   ```

2. **Consider using a decimal library for critical calculations:**
   ```javascript
   import Decimal from 'decimal.js';
   const total = new Decimal(price).minus(discount).toFixed(2);
   ```

3. **Database: Always use NUMERIC/DECIMAL types (not FLOAT/REAL):**
   ```sql
   final_bill_amount NUMERIC(10, 2) -- Exact precision
   ```

4. **Constraints: Consider using tolerance for floating-point comparisons:**
   ```sql
   CHECK (ABS(final_bill_amount - (bill_amount - deductions)) < 0.01)
   ```

## Related Files

- **Fix:** `d:\Aqura\frontend\src\lib\components\admin\vendor\MonthDetails.svelte`
- **Test Scripts:**
  - `d:\Aqura\test-floating-point-fix.cjs`
  - `d:\Aqura\check-vendor-payment-constraints.cjs`
  - `d:\Aqura\test-cent-arithmetic.cjs`
  - `d:\Aqura\test-tofixed-approach.cjs`

## Additional Notes

This is a classic floating-point vs exact decimal issue that occurs when JavaScript (IEEE 754) interacts with SQL databases (NUMERIC/DECIMAL types). The constraint is doing its own calculation in PostgreSQL's exact NUMERIC arithmetic and comparing it to the value we send, which must match exactly.

The solution (cent arithmetic + toFixed) ensures that:
1. Calculations are done in exact integers
2. The result is formatted as an exact decimal string
3. PostgreSQL receives a value it can cleanly convert to match its own NUMERIC calculation

---

**Status:** ✅ FIXED  
**Tested:** ✅ YES (multiple test scripts confirm the fix)  
**Deployed:** Ready for deployment
