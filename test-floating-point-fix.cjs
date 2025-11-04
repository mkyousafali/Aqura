/**
 * Test script to verify the floating-point fix for vendor_payment_schedule deductions
 * 
 * This demonstrates why 11837.30 was failing and how rounding fixes it
 */

console.log('🧪 FLOATING-POINT PRECISION FIX TEST\n');
console.log('='.repeat(80));

// The problematic values
const billAmount = 22401.25;
const grrAmount = 11837.30;
const discountAmount = 0;
const priAmount = 0;

console.log('\n📊 INPUT VALUES:');
console.log(`  bill_amount: ${billAmount}`);
console.log(`  grr_amount: ${grrAmount}`);
console.log(`  discount_amount: ${discountAmount}`);
console.log(`  pri_amount: ${priAmount}`);

// Calculate WITHOUT rounding (the problem)
const rawCalculation = billAmount - grrAmount - discountAmount - priAmount;
console.log('\n❌ WITHOUT ROUNDING (FAILS):');
console.log(`  Calculation: ${billAmount} - ${grrAmount} - ${discountAmount} - ${priAmount}`);
console.log(`  Result: ${rawCalculation}`);
console.log(`  Result (full precision): ${rawCalculation.toFixed(20)}`);
console.log(`  Expected: 10563.95`);
console.log(`  Match: ${rawCalculation === 10563.95 ? '✅ YES' : '❌ NO'}`);
console.log(`  Error: ${Math.abs(rawCalculation - 10563.95).toExponential()}`);

// Calculate WITH rounding (the fix)
const roundedCalculation = Math.round((billAmount - grrAmount - discountAmount - priAmount) * 100) / 100;
console.log('\n✅ WITH ROUNDING (WORKS):');
console.log(`  Calculation: Math.round((${billAmount} - ${grrAmount} - ${discountAmount} - ${priAmount}) * 100) / 100`);
console.log(`  Result: ${roundedCalculation}`);
console.log(`  Result (full precision): ${roundedCalculation.toFixed(20)}`);
console.log(`  Expected: 10563.95`);
console.log(`  Match: ${roundedCalculation === 10563.95 ? '✅ YES' : '❌ NO'}`);

// Test the working case
console.log('\n\n🔬 TESTING THE WORKING CASE (11000.37):');
console.log('='.repeat(80));

const workingGrr = 11000.37;
const rawWorking = billAmount - workingGrr;
const roundedWorking = Math.round((billAmount - workingGrr) * 100) / 100;

console.log(`  Without rounding: ${rawWorking.toFixed(20)}`);
console.log(`  With rounding: ${roundedWorking.toFixed(20)}`);
console.log(`  Difference: ${Math.abs(rawWorking - roundedWorking).toExponential()}`);

// Test multiple problematic values
console.log('\n\n🎯 TESTING MULTIPLE VALUES:');
console.log('='.repeat(80));

const testCases = [
  { bill: 22401.25, deduction: 11837.30, expected: 10563.95 },
  { bill: 22401.25, deduction: 11000.37, expected: 11400.88 },
  { bill: 10000.00, deduction: 3333.33, expected: 6666.67 },
  { bill: 15750.50, deduction: 5250.17, expected: 10500.33 },
  { bill: 9999.99, deduction: 1234.56, expected: 8765.43 }
];

testCases.forEach((test, idx) => {
  const raw = test.bill - test.deduction;
  const rounded = Math.round((test.bill - test.deduction) * 100) / 100;
  const rawMatch = raw === test.expected;
  const roundedMatch = rounded === test.expected;
  
  console.log(`\nTest ${idx + 1}: ${test.bill} - ${test.deduction}`);
  console.log(`  Raw: ${raw.toFixed(10)} ${rawMatch ? '✅' : '❌'}`);
  console.log(`  Rounded: ${rounded.toFixed(10)} ${roundedMatch ? '✅' : '❌'}`);
  console.log(`  Expected: ${test.expected.toFixed(10)}`);
});

console.log('\n\n📝 SUMMARY:');
console.log('='.repeat(80));
console.log('The fix: Math.round(value * 100) / 100');
console.log('This ensures all monetary values are rounded to exactly 2 decimal places');
console.log('before being sent to the database, avoiding floating-point precision issues.');
console.log('\n✅ The fix has been applied to MonthDetails.svelte in the saveAmountAdjustment function');
