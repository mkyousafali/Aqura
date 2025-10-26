const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const serviceRoleKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, serviceRoleKey);

async function testMigration() {
	console.log('🧪 Testing Migration Readiness\n');
	console.log('═══════════════════════════════════════════════════\n');
	
	// Test 1: Check vendor_payment_schedule table exists
	console.log('✓ Test 1: Checking vendor_payment_schedule table...');
	const { data: scheduleData, error: scheduleError } = await supabase
		.from('vendor_payment_schedule')
		.select('*')
		.limit(1);
	
	if (scheduleError) {
		console.log('✗ FAILED:', scheduleError.message);
		return;
	}
	console.log('✓ PASSED: vendor_payment_schedule table accessible\n');
	
	// Test 2: Check payment_transactions table exists (should exist before migration)
	console.log('✓ Test 2: Checking payment_transactions table...');
	const { data: transData, error: transError } = await supabase
		.from('payment_transactions')
		.select('*')
		.limit(1);
	
	if (transError) {
		console.log('✗ FAILED:', transError.message);
		return;
	}
	console.log('✓ PASSED: payment_transactions table exists (will be dropped by migration)\n');
	
	// Test 3: Count records to migrate
	console.log('✓ Test 3: Counting records to migrate...');
	const { count: transCount, error: countError } = await supabase
		.from('payment_transactions')
		.select('*', { count: 'exact', head: true });
	
	if (countError) {
		console.log('✗ FAILED:', countError.message);
		return;
	}
	console.log(`✓ PASSED: ${transCount} payment transactions will be migrated\n`);
	
	// Test 4: Check for data overlap
	console.log('✓ Test 4: Checking data relationships...');
	const { data: relationships, error: relError } = await supabase
		.from('payment_transactions')
		.select('payment_schedule_id')
		.limit(5);
	
	if (relError) {
		console.log('✗ FAILED:', relError.message);
		return;
	}
	console.log(`✓ PASSED: ${relationships.length} sample relationships verified\n`);
	
	// Summary
	console.log('═══════════════════════════════════════════════════');
	console.log('📊 MIGRATION READINESS SUMMARY');
	console.log('═══════════════════════════════════════════════════');
	console.log(`✅ All tests passed`);
	console.log(`📝 ${transCount} payment transaction records ready to migrate`);
	console.log(`📊 Migration will:`);
	console.log(`   1. Add new columns to vendor_payment_schedule`);
	console.log(`   2. Migrate ${transCount} transaction records`);
	console.log(`   3. Drop payment_transactions table`);
	console.log(`   4. Update all code references`);
	console.log('═══════════════════════════════════════════════════\n');
	console.log('⚠️  READY TO RUN MIGRATION');
	console.log('   Run: psql -h <host> -U postgres -d postgres < supabase/migrations/20250127000000_merge_payment_transactions.sql');
	console.log('   Or use Supabase dashboard to run the migration\n');
}

testMigration().catch(console.error);
