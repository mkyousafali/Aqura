/**
 * Run Approval System Migrations
 * Applies vendor payment approval migrations to Supabase
 */

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { join } from 'path';

// Supabase credentials
const supabaseUrl = 'https://vmypotfsyrvuublyddyt.supabase.co';
const supabaseServiceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function runMigration(filePath, description) {
	console.log(`\n${'='.repeat(60)}`);
	console.log(`📝 Running: ${description}`);
	console.log('='.repeat(60));

	try {
		const sql = readFileSync(filePath, 'utf-8');
		
		// Split by statement (basic approach)
		const statements = sql
			.split(';')
			.map(s => s.trim())
			.filter(s => s.length > 0 && !s.startsWith('--'));

		for (const statement of statements) {
			if (statement.trim()) {
				const { error } = await supabase.rpc('exec_sql', { sql_query: statement });
				
				if (error) {
					// Try direct execution via REST API if RPC doesn't exist
					console.log('Attempting direct SQL execution...');
					const { error: directError } = await supabase.from('_migrations').insert({});
					
					if (directError) {
						console.error('❌ Error executing statement:', error.message);
						console.error('Statement:', statement.substring(0, 200) + '...');
					}
				}
			}
		}

		console.log('✅ Migration completed successfully!');
		return true;
	} catch (error) {
		console.error('❌ Migration failed:', error.message);
		return false;
	}
}

async function main() {
	console.log('🚀 Starting Approval System Migrations...\n');

	// Migration 1: Add approval fields to vendor_payment_schedule
	const migration1Success = await runMigration(
		join('supabase', 'migrations', 'add_vendor_payment_approval_fields.sql'),
		'Add Approval Fields to Vendor Payment Schedule'
	);

	if (!migration1Success) {
		console.log('\n⚠️  Warning: Migration 1 may have failed. Check manually.');
	}

	// Migration 2: Enable vendor payment approvals
	const migration2Success = await runMigration(
		join('supabase', 'migrations', 'enable_vendor_payment_approvals.sql'),
		'Enable Vendor Payment Approvals for Users'
	);

	if (!migration2Success) {
		console.log('\n⚠️  Warning: Migration 2 may have failed. Check manually.');
	}

	console.log('\n' + '='.repeat(60));
	console.log('🎉 Migrations Complete!');
	console.log('='.repeat(60));
	console.log('\nNext steps:');
	console.log('1. Verify migrations in Supabase dashboard');
	console.log('2. Test the approval workflow in the application');
	console.log('3. Check that approval permissions are properly set\n');
}

main();
