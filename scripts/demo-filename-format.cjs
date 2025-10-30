/**
 * Test Filename Generation with Employee Name
 * Demonstrates the new filename format
 */

// Simulate the filename generation function
function generateWarningImagePath(warningReference, employeeName = 'Unknown', employeeId = null) {
	const now = new Date();
	const year = now.getFullYear();
	const month = String(now.getMonth() + 1).padStart(2, '0');
	const timestamp = now.getTime();
	
	// Sanitize employee name for filename
	const sanitizedName = employeeName
		.replace(/[^a-zA-Z0-9\s]/g, '')
		.trim()
		.replace(/\s+/g, '_')
		.toLowerCase();
	
	// Sanitize warning reference
	const sanitizedRef = warningReference.replace(/[^a-zA-Z0-9-]/g, '_');
	
	// Build filename parts
	let filenameParts = [sanitizedName, sanitizedRef];
	
	// Add employee ID if provided
	if (employeeId) {
		const shortId = employeeId.substring(0, 8);
		filenameParts.push(shortId);
	}
	
	// Add timestamp
	filenameParts.push(timestamp.toString());
	
	const filename = filenameParts.join('_') + '.png';
	
	return `${year}/${month}/${filename}`;
}

console.log('🎯 Warning Image Filename Generation Examples\n');
console.log('='.repeat(60));

// Test various employee names
const testCases = [
	{
		name: 'John Doe',
		reference: 'WRN-20251030-0001',
		employeeId: 'a1b2c3d4-5678-90ab-cdef-1234567890ab'
	},
	{
		name: 'Abdul Rahman Al-Sayed',
		reference: 'WRN-20251030-0002',
		employeeId: 'b2c3d4e5-6789-01bc-def0-234567890abc'
	},
	{
		name: "Maria O'Connor",
		reference: 'WRN-20251030-0003',
		employeeId: 'c3d4e5f6-7890-12cd-ef01-34567890abcd'
	},
	{
		name: 'José García-López',
		reference: 'WRN-20251030-0004',
		employeeId: 'd4e5f6a7-8901-23de-f012-4567890abcde'
	},
	{
		name: 'Li Wei Zhang',
		reference: 'WRN-20251030-0005',
		employeeId: 'e5f6a7b8-9012-34ef-0123-567890abcdef'
	},
	{
		name: 'Unknown Employee',
		reference: 'WRN-20251030-0006',
		employeeId: null // No employee ID
	}
];

testCases.forEach((testCase, index) => {
	console.log(`\n${index + 1}. Employee: ${testCase.name}`);
	console.log(`   Reference: ${testCase.reference}`);
	console.log(`   Employee ID: ${testCase.employeeId || 'N/A'}`);
	
	const path = generateWarningImagePath(
		testCase.reference,
		testCase.name,
		testCase.employeeId
	);
	
	console.log(`   📁 Filename: ${path}`);
	console.log(`   🔗 Full URL: https://vmypotfsyrvuublyddyt.supabase.co/storage/v1/object/public/warning-documents/${path}`);
});

console.log('\n' + '='.repeat(60));
console.log('\n✅ Filename Format Benefits:');
console.log('   • Employee name clearly visible');
console.log('   • Searchable by employee name');
console.log('   • Unique identifier prevents conflicts');
console.log('   • Organized by date (YYYY/MM)');
console.log('   • Special characters safely removed');
console.log('   • Consistent lowercase format');

console.log('\n📊 Filename Components:');
console.log('   [employeename]_[reference]_[employee_id]_[timestamp].png');
console.log('   └─ Sanitized   └─ Warning   └─ First 8   └─ Unix time');
console.log('      lowercase      number        chars        (unique)');

console.log('\n💡 Usage in Code:');
console.log('   const path = generateWarningImagePath(');
console.log('     "WRN-20251030-0001",              // Warning reference');
console.log('     "John Doe",                       // Employee name');
console.log('     "a1b2c3d4-5678-90ab-..."         // Employee UUID');
console.log('   );');
console.log('   // Returns: "2025/10/john_doe_WRN-20251030-0001_a1b2c3d4_1730304000000.png"');

console.log('\n');
