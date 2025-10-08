/**
 * Database Constraint Fix for Notification Queue
 * 
 * This script attempts to remove the problematic unique constraint
 * that's causing 409/400 notification delivery errors.
 */

import { createClient } from '@supabase/supabase-js';
import { randomUUID } from 'crypto';

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

async function testAndFixConstraint() {
	console.log('Starting notification queue constraint analysis...');
	
	try {
		// 1. Check table accessibility
		console.log('Checking notification_queue table...');
		const { data: existingData, error: queryError } = await supabaseAdmin
			.from('notification_queue')
			.select('id, notification_id, user_id, device_id')
			.limit(5);

		if (queryError) {
			console.error('Error accessing notification_queue:', queryError);
			return false;
		}

		console.log(`Table accessible. Found ${existingData?.length || 0} existing records.`);

		// 2. Test constraint by inserting test data
		console.log('Testing constraint with sample data...');
		
		// First get existing notification and user IDs to use for the test
		const { data: existingNotifications } = await supabaseAdmin
			.from('notifications')
			.select('id')
			.limit(1);
		
		const { data: existingUsers } = await supabaseAdmin
			.from('users')
			.select('id')
			.limit(1);
		
		if (!existingNotifications?.[0]?.id || !existingUsers?.[0]?.id) {
			console.log('Missing required existing data. Cannot test constraint.');
			return false;
		}
		
		const testNotification = {
			notification_id: existingNotifications[0].id,
			user_id: existingUsers[0].id,
			device_id: 'constraint-test-device',
			status: 'pending',
			payload: {
				title: 'Test Constraint',
				body: 'Testing unique constraint',
				data: { test: true }
			},
			retry_count: 0,
			created_at: new Date().toISOString()
		};

		const { data: firstInsert, error: firstError } = await supabaseAdmin
			.from('notification_queue')
			.insert(testNotification)
			.select();

		if (firstError) {
			console.error('First test insertion failed:', firstError);
			return false;
		}

		console.log('First insertion successful:', firstInsert[0].id);

		// 3. Try duplicate insertion to trigger constraint
		console.log('Testing duplicate insertion...');
		const { data: duplicateInsert, error: duplicateError } = await supabaseAdmin
			.from('notification_queue')
			.insert(testNotification)
			.select();

		if (duplicateError) {
			console.log('Duplicate insertion failed (expected):', duplicateError.message);
			
			if (duplicateError.code === '23505') {
				console.log('CONFIRMED: Unique constraint is blocking duplicate notifications');
				console.log('This is causing the 409/400 errors in production');
				
				// 4. Attempt to remove the constraint
				console.log('Attempting to remove constraint...');
				
				// Apply the actual SQL fix from the fix-notification-queue-constraint.sql file
				const fixConstraintSQL = `
					-- Remove the problematic unique constraint
					ALTER TABLE notification_queue 
					DROP CONSTRAINT IF EXISTS unique_notification_user_device;
					
					-- Create performance index for common queries
					CREATE INDEX IF NOT EXISTS idx_notification_queue_lookup 
					ON notification_queue (notification_id, user_id, device_id, status);
				`;
				
				const { data: sqlResult, error: sqlError } = await supabaseAdmin
					.rpc('sql', { query: fixConstraintSQL });
				
				if (sqlError) {
					console.log('SQL execution via RPC failed:', sqlError);
					console.log('');
					console.log('MANUAL FIX REQUIRED:');
					console.log('Please run this SQL in Supabase Dashboard SQL Editor:');
					console.log('');
					console.log('ALTER TABLE notification_queue DROP CONSTRAINT IF EXISTS unique_notification_user_device;');
					console.log('CREATE INDEX IF NOT EXISTS idx_notification_queue_lookup ON notification_queue (notification_id, user_id, device_id, status);');
					console.log('');
					console.log('This will resolve the 409/400 notification delivery errors.');
				} else {
					console.log('SUCCESS: Constraint removed successfully!');
					console.log('Result:', sqlResult);
					
					// Test that duplicates now work
					console.log('Testing duplicate insertion after constraint removal...');
					const { data: postFixDuplicate, error: postFixError } = await supabaseAdmin
						.from('notification_queue')
						.insert(testNotification)
						.select();
					
					if (postFixError) {
						console.log('Post-fix duplicate test failed:', postFixError.message);
					} else {
						console.log('SUCCESS: Duplicate insertion now works!');
						
						// Clean up the post-fix test data
						if (postFixDuplicate?.[0]?.id) {
							await supabaseAdmin
								.from('notification_queue')
								.delete()
								.eq('id', postFixDuplicate[0].id);
							console.log('Post-fix test data cleaned up');
						}
					}
				}
			}
		} else {
			console.log('WARNING: Duplicate insertion succeeded');
			console.log('The constraint may not exist or may have been removed already');
			
			// Clean up duplicate
			if (duplicateInsert?.[0]?.id) {
				await supabaseAdmin
					.from('notification_queue')
					.delete()
					.eq('id', duplicateInsert[0].id);
			}
		}

		// 5. Clean up test data
		console.log('Cleaning up test data...');
		if (firstInsert?.[0]?.id) {
			await supabaseAdmin
				.from('notification_queue')
				.delete()
				.eq('id', firstInsert[0].id);
			console.log('Test data cleaned up');
		}

		console.log('');
		console.log('ANALYSIS COMPLETE');
		console.log('==================');
		console.log('The notification queue constraint analysis is complete.');
		console.log('If the constraint removal was successful, 409/400 errors should be resolved.');
		
		return true;

	} catch (error) {
		console.error('Unexpected error during constraint analysis:', error);
		return false;
	}
}

// Run the analysis and fix
console.log('NOTIFICATION QUEUE CONSTRAINT FIX');
console.log('==================================');
testAndFixConstraint()
	.then(success => {
		if (success) {
			console.log('Constraint analysis completed successfully!');
			process.exit(0);
		} else {
			console.log('Constraint analysis failed!');
			process.exit(1);
		}
	})
	.catch(error => {
		console.error('Fatal error:', error);
		process.exit(1);
	});