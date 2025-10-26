import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function checkRelationship() {
	console.log('🔍 Checking users and hr_employees relationship...\n');

	// Check users table structure
	const { data: usersData, error: usersError } = await supabase
		.from('users')
		.select('*')
		.limit(1);

	if (usersData && usersData[0]) {
		console.log('✅ Users table columns:', Object.keys(usersData[0]));
	}

	// Check hr_employees table structure
	const { data: empData, error: empError } = await supabase
		.from('hr_employees')
		.select('*')
		.limit(1);

	if (empData && empData[0]) {
		console.log('✅ HR Employees table columns:', Object.keys(empData[0]));
	}

	// Try to join users with hr_employees
	console.log('\n🔗 Testing join with employee_id...');
	const { data: joinTest1, error: joinError1 } = await supabase
		.from('users')
		.select(`
			id,
			username,
			employee_id,
			hr_employees!users_employee_id_fkey (
				id,
				employee_id,
				name
			)
		`)
		.limit(3);

	if (joinTest1) {
		console.log('✅ Join successful with employee_id foreign key:');
		console.log(JSON.stringify(joinTest1, null, 2));
	} else {
		console.log('❌ Join failed:', joinError1?.message);
	}

	// Try alternative join
	console.log('\n🔗 Testing alternative join...');
	const { data: joinTest2, error: joinError2 } = await supabase
		.from('users')
		.select(`
			id,
			username,
			employee_id,
			hr_employees (
				id,
				employee_id,
				name
			)
		`)
		.limit(3);

	if (joinTest2) {
		console.log('✅ Alternative join successful:');
		console.log(JSON.stringify(joinTest2, null, 2));
	} else {
		console.log('❌ Alternative join failed:', joinError2?.message);
	}
}

checkRelationship().catch(console.error);
