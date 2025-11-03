/**
 * Check Table Structures
 * Query vendor_payment_schedule and approval_permissions tables
 * Using Supabase Service Role Key
 */

import { createClient } from '@supabase/supabase-js';

// Hardcoded credentials (from .env file)
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

if (!supabaseUrl || !supabaseServiceKey) {
	console.error('❌ Missing Supabase credentials in .env file');
	process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

console.log('🔍 Checking Table Structures...\n');

async function checkTableStructure(tableName) {
	console.log(`\n${'='.repeat(60)}`);
	console.log(`📊 TABLE: ${tableName}`);
	console.log('='.repeat(60));

	try {
		// Query to get column information
		const { data, error } = await supabase.rpc('get_table_columns', {
			table_name: tableName
		});

		if (error) {
			// If RPC doesn't exist, try a direct query to information_schema
			console.log('Trying alternative method...');
			const { data: schemaData, error: schemaError } = await supabase
				.from(tableName)
				.select('*')
				.limit(0);

			if (schemaError) {
				console.error(`❌ Error querying table: ${schemaError.message}`);
				return null;
			}

			// Get a sample row to understand structure
			const { data: sampleData, error: sampleError } = await supabase
				.from(tableName)
				.select('*')
				.limit(1);

			if (sampleError) {
				console.error(`❌ Error getting sample: ${sampleError.message}`);
			}

			if (sampleData && sampleData.length > 0) {
				console.log('\n📋 Column Names (from sample data):');
				const columns = Object.keys(sampleData[0]);
				columns.forEach((col, idx) => {
					const value = sampleData[0][col];
					const type = typeof value;
					console.log(`  ${idx + 1}. ${col} (${type})`);
				});
				return columns;
			} else {
				// Table exists but is empty, just list what we can
				console.log('⚠️  Table exists but is empty');
				return [];
			}
		}

		console.log('✅ Table structure retrieved');
		console.table(data);
		return data;
	} catch (err) {
		console.error(`❌ Error checking table ${tableName}:`, err.message);
		return null;
	}
}

async function getRowCount(tableName) {
	try {
		const { count, error } = await supabase
			.from(tableName)
			.select('*', { count: 'exact', head: true });

		if (error) {
			console.error(`Error counting ${tableName}:`, error.message);
			return 0;
		}

		return count || 0;
	} catch (err) {
		console.error(`Error counting ${tableName}:`, err.message);
		return 0;
	}
}

async function checkApprovalPermissions() {
	console.log('\n📊 APPROVAL PERMISSIONS SAMPLE DATA');
	console.log('='.repeat(60));

	try {
		const { data, error } = await supabase
			.from('approval_permissions')
			.select('*')
			.limit(3);

		if (error) {
			console.error('❌ Error:', error.message);
			return;
		}

		if (data && data.length > 0) {
			console.log(`Found ${data.length} records:\n`);
			data.forEach((record, idx) => {
				console.log(`Record ${idx + 1}:`);
				console.log(`  User ID: ${record.user_id}`);
				console.log(`  Can Approve Vendor Payments: ${record.can_approve_vendor_payments}`);
				console.log(`  Vendor Payment Limit: ${record.vendor_payment_amount_limit}`);
				console.log(`  Can Approve Requisitions: ${record.can_approve_requisitions}`);
				console.log(`  Can Approve Single Bill: ${record.can_approve_single_bill}`);
				console.log(`  Can Approve Multiple Bill: ${record.can_approve_multiple_bill}`);
				console.log(`  Can Approve Recurring Bill: ${record.can_approve_recurring_bill}`);
				console.log(`  Active: ${record.is_active}`);
				console.log('');
			});
		} else {
			console.log('⚠️  No records found');
		}
	} catch (err) {
		console.error('❌ Error:', err.message);
	}
}

async function checkVendorPaymentSchedule() {
	console.log('\n📊 VENDOR PAYMENT SCHEDULE SAMPLE DATA');
	console.log('='.repeat(60));

	try {
		const { data, error } = await supabase
			.from('vendor_payment_schedule')
			.select('*')
			.limit(3);

		if (error) {
			console.error('❌ Error:', error.message);
			return;
		}

		if (data && data.length > 0) {
			console.log(`Found ${data.length} records:\n`);
			data.forEach((record, idx) => {
				console.log(`Record ${idx + 1}:`);
				Object.keys(record).forEach(key => {
					console.log(`  ${key}: ${record[key]}`);
				});
				console.log('');
			});
		} else {
			console.log('⚠️  No records found');
		}
	} catch (err) {
		console.error('❌ Error:', err.message);
	}
}

async function main() {
	// Check approval_permissions table
	const approvalPermissionsStructure = await checkTableStructure('approval_permissions');
	const approvalPermissionsCount = await getRowCount('approval_permissions');
	console.log(`\n📈 Total Records: ${approvalPermissionsCount}`);

	// Check vendor_payment_schedule table
	const vendorPaymentScheduleStructure = await checkTableStructure('vendor_payment_schedule');
	const vendorPaymentScheduleCount = await getRowCount('vendor_payment_schedule');
	console.log(`\n📈 Total Records: ${vendorPaymentScheduleCount}`);

	// Get sample data
	await checkApprovalPermissions();
	await checkVendorPaymentSchedule();

	console.log('\n✅ Table structure check complete!\n');
}

main();
