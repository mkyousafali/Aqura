// Test date parsing for the payment
const paymentDueDate = "2025-12-10";
const paymentDate = new Date(paymentDueDate);

console.log('\n📅 Date Parsing Test:');
console.log('='.repeat(80));
console.log('Payment due_date:', paymentDueDate);
console.log('Parsed Date:', paymentDate);
console.log('Date String:', paymentDate.toDateString());
console.log('ISO String:', paymentDate.toISOString());
console.log('Month (0-indexed):', paymentDate.getMonth(), '(December = 11)');
console.log('Year:', paymentDate.getFullYear());
console.log('Day:', paymentDate.getDate());

console.log('\n🔍 Checking December 10, 2025:');
const testDay = new Date(2025, 11, 10); // December 10, 2025
console.log('Test Date:', testDay);
console.log('Test Date String:', testDay.toDateString());
console.log('Match:', paymentDate.toDateString() === testDay.toDateString());

console.log('\n✅ Complete!\n');
