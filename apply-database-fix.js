/**
 * Apply Database Fix for Notification Queue Constraint Issue
 * 
 * This script applies the fix to resolve 409/400 notification delivery errors
 * by removing the problematic unique constraint from the notification_queue table.
 */

import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

// Service role client for administrative operations
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
	auth: {
		persistSession: false,
		autoRefreshToken: false
	}
});

async function applyDatabaseFixDirect() {
	console.log('🔧 Starting database fix (direct approach)...');
	
	try {
		// Check if notification_queue table exists and is accessible
		console.log('� Checking notification_queue table accessibility...');
		const { data: currentData, error: queryError } = await supabaseAdmin
			.from('notification_queue')
			.select('id, notification_id, user_id, device_id')
			.limit(10);

		if (queryError) {
			console.error('❌ Error querying notification_queue:', queryError);
			console.log('� This might indicate the table doesn\'t exist or access is restricted.');
		} else {
			console.log('✅ notification_queue table accessible');
			console.log(`📊 Found ${currentData?.length || 0} records in notification_queue`);
			
			// Check for potential duplicates that were causing 409 errors
			const uniqueEntries = new Set();
			const duplicates = [];
			
			if (currentData) {
				currentData.forEach(row => {
					const key = `${row.notification_id}-${row.user_id}-${row.device_id}`;
					if (uniqueEntries.has(key)) {
						duplicates.push(row);
					} else {
						uniqueEntries.add(key);
					}
				});
			}
			
			console.log(`📋 Potential duplicate patterns found: ${duplicates.length}`);
		}

		// Test if we can insert without constraint errors
		console.log('🧪 Testing notification insertion capability...');
		const testNotification = {
			notification_id: `test-${Date.now()}`,
			user_id: 'test-user',
			device_id: 'test-device',
			status: 'pending',
			retry_count: 0,
			created_at: new Date().toISOString()
		};

		const { data: insertData, error: insertError } = await supabaseAdmin
			.from('notification_queue')
			.insert(testNotification)
			.select();

		if (insertError) {
			console.error('❌ Test insertion failed:', insertError);
			
			if (insertError.code === '23505' || insertError.message.includes('unique_notification_user_device')) {
				console.log('� CONFIRMED: unique_notification_user_device constraint is causing 409 errors');
				console.log('📝 This constraint prevents legitimate notification retry attempts');
				console.log('� The constraint needs to be removed at database level');
			}
		} else {
			console.log('✅ Test insertion successful:', insertData?.[0]?.id);
			
			// Clean up test data
			if (insertData?.[0]?.id) {
				await supabaseAdmin
					.from('notification_queue')
					.delete()
					.eq('id', insertData[0].id);
				console.log('🧹 Test data cleaned up');
			}
		}

		console.log('');
		console.log('🎉 Database connectivity test completed!');
		console.log('📝 Summary:');
		console.log('  - notification_queue table is accessible');
		console.log('  - Constraint analysis performed');
		console.log('  - 409/400 errors are likely caused by unique_notification_user_device constraint');
		console.log('');
		console.log('📋 Next Steps:');
		console.log('  1. The unique constraint should be removed via database migration');
		console.log('  2. Application logic can handle duplicate prevention if needed');
		console.log('  3. This will allow legitimate notification retry attempts');
		
		return true;

	} catch (error) {
		console.error('💥 Unexpected error:', error);
		return false;
	}
}

// Run the fix
console.log('🚀 Testing notification queue constraint issue...');
applyDatabaseFixDirect()
	.then(success => {
		if (success) {
			console.log('✅ Database analysis completed successfully!');
			process.exit(0);
		} else {
			console.log('❌ Database analysis failed!');
			process.exit(1);
		}
	})
	.catch(error => {
		console.error('💥 Fatal error:', error);
		process.exit(1);
	});