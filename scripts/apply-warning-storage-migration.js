/**
 * Apply Warning Images Storage Migration
 * Run this script to create the storage bucket and policies
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Load environment variables
require('dotenv').config({ path: path.join(__dirname, '../frontend/.env') });

const supabaseUrl = process.env.VITE_SUPABASE_URL;
const supabaseServiceKey = process.env.VITE_SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
	console.error('❌ Missing Supabase credentials in .env file');
	process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function applyMigration() {
	console.log('🚀 Starting Warning Images Storage Migration...\n');

	try {
		// Read the migration file
		const migrationPath = path.join(__dirname, '../supabase/migrations/20251030000001_warning_images_storage.sql');
		const migrationSQL = fs.readFileSync(migrationPath, 'utf8');

		console.log('📄 Migration file loaded');
		console.log('📋 Executing migration...\n');

		// Split SQL into individual statements
		const statements = migrationSQL
			.split(';')
			.map(s => s.trim())
			.filter(s => s.length > 0 && !s.startsWith('--'));

		let successCount = 0;
		let errorCount = 0;

		// Execute each statement
		for (let i = 0; i < statements.length; i++) {
			const statement = statements[i] + ';';
			
			// Skip comments
			if (statement.startsWith('--')) continue;
			
			console.log(`\n📌 Executing statement ${i + 1}/${statements.length}...`);
			
			try {
				const { data, error } = await supabase.rpc('exec_sql', { sql: statement });
				
				if (error) {
					// Some errors are expected (e.g., bucket already exists)
					if (error.message.includes('already exists') || 
						error.message.includes('duplicate')) {
						console.log('⚠️  Resource already exists, skipping...');
					} else {
						console.error('❌ Error:', error.message);
						errorCount++;
					}
				} else {
					console.log('✅ Success');
					successCount++;
				}
			} catch (err) {
				console.error('❌ Execution error:', err.message);
				errorCount++;
			}
		}

		console.log('\n' + '='.repeat(50));
		console.log(`✅ Migration completed!`);
		console.log(`   Successful: ${successCount}`);
		console.log(`   Errors: ${errorCount}`);
		console.log('='.repeat(50));

		// Verify bucket was created
		console.log('\n🔍 Verifying storage bucket...');
		const { data: buckets, error: bucketsError } = await supabase.storage.listBuckets();
		
		if (bucketsError) {
			console.error('❌ Error checking buckets:', bucketsError.message);
		} else {
			const warningBucket = buckets.find(b => b.id === 'warning-documents');
			if (warningBucket) {
				console.log('✅ Storage bucket "warning-documents" exists!');
				console.log('   Public:', warningBucket.public);
				console.log('   Created:', warningBucket.created_at);
			} else {
				console.log('⚠️  Storage bucket "warning-documents" not found');
				console.log('   You may need to create it manually in Supabase Dashboard');
			}
		}

		console.log('\n🎉 Migration process complete!');
		console.log('\n📝 Next steps:');
		console.log('   1. Verify the storage bucket in Supabase Dashboard');
		console.log('   2. Test image upload functionality');
		console.log('   3. Check storage policies are working correctly\n');

	} catch (error) {
		console.error('\n❌ Migration failed:', error.message);
		process.exit(1);
	}
}

// Run migration
applyMigration();
