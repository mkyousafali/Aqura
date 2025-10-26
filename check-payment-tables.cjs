const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkTables() {
	console.log('=== VENDOR_PAYMENT_SCHEDULE TABLE ===\n');
	
	// Get table structure
	const { data: scheduleData, error: scheduleError } = await supabase
		.from('vendor_payment_schedule')
		.select('*')
		.limit(3);
	
	if (scheduleError) {
		console.error('Error fetching vendor_payment_schedule:', scheduleError);
	} else {
		console.log('Sample rows:', scheduleData.length);
		if (scheduleData.length > 0) {
			console.log('Columns:', Object.keys(scheduleData[0]));
			console.log('\nSample data:');
			scheduleData.forEach((row, i) => {
				console.log(`\nRow ${i + 1}:`, JSON.stringify(row, null, 2));
			});
		}
	}
	
	console.log('\n\n=== PAYMENT_TRANSACTIONS TABLE ===\n');
	
	const { data: transData, error: transError } = await supabase
		.from('payment_transactions')
		.select('*')
		.limit(3);
	
	if (transError) {
		console.error('Error fetching payment_transactions:', transError);
	} else {
		console.log('Sample rows:', transData.length);
		if (transData.length > 0) {
			console.log('Columns:', Object.keys(transData[0]));
			console.log('\nSample data:');
			transData.forEach((row, i) => {
				console.log(`\nRow ${i + 1}:`, JSON.stringify(row, null, 2));
			});
		}
	}
	
	// Check for any relationships
	console.log('\n\n=== CHECKING RELATIONSHIPS ===\n');
	
	const { data: joinData, error: joinError } = await supabase
		.from('vendor_payment_schedule')
		.select(`
			*,
			payment_transactions (*)
		`)
		.limit(2);
	
	if (joinError) {
		console.log('No direct foreign key relationship found (expected)');
	} else {
		console.log('Relationship data:', JSON.stringify(joinData, null, 2));
	}
}

checkTables().catch(console.error);
