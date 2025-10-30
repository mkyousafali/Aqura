/**
 * Delete Employee Warnings Data
 * Run this to clear the employee_warnings table
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function deleteWarnings() {
	console.log('⚠️  WARNING: This will delete all employee warnings and their history!\n');
	
	try {
		// Get count before deletion
		const { count: warningCount, error: countError } = await supabase
			.from('employee_warnings')
			.select('*', { count: 'exact', head: true });
		
		if (countError) throw countError;
		
		const { count: historyCount } = await supabase
			.from('employee_warning_history')
			.select('*', { count: 'exact', head: true });
		
		console.log(`📊 Current warning records: ${warningCount}`);
		console.log(`� Current history records: ${historyCount || 0}`);
		
		// Step 1: Delete warning history first (due to foreign key)
		if (historyCount > 0) {
			console.log('\n🗑️  Step 1: Deleting warning history...');
			const { error: historyError } = await supabase
				.from('employee_warning_history')
				.delete()
				.neq('id', '00000000-0000-0000-0000-000000000000');
			
			if (historyError) throw historyError;
			console.log('✅ Warning history deleted');
		}
		
		// Step 2: Delete warnings
		console.log('\n🗑️  Step 2: Deleting warnings...');
		const { error: warningError } = await supabase
			.from('employee_warnings')
			.delete()
			.neq('id', '00000000-0000-0000-0000-000000000000');
		
		if (warningError) throw warningError;
		
		// Verify deletion
		const { count: afterCount } = await supabase
			.from('employee_warnings')
			.select('*', { count: 'exact', head: true });
		
		console.log('\n✅ Deletion complete!');
		console.log(`📊 Warnings before: ${warningCount}`);
		console.log(`📊 Warnings after: ${afterCount}`);
		console.log(`🗑️  Total deleted: ${warningCount - afterCount}`);
		
	} catch (error) {
		console.error('\n❌ Error deleting warnings:', error.message);
		process.exit(1);
	}
}

// Run deletion
deleteWarnings();
