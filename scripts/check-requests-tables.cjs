/**
 * Check Requests Tables Structure
 * This script checks the structure of tables needed for the Requests Manager
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Read .env file manually
const envPath = path.join(__dirname, '../frontend/.env');
const envContent = fs.readFileSync(envPath, 'utf-8');
const envVars = {};

envContent.split('\n').forEach(line => {
	const trimmed = line.trim();
	if (trimmed && !trimmed.startsWith('#')) {
		const [key, ...valueParts] = trimmed.split('=');
		if (key && valueParts.length > 0) {
			envVars[key.trim()] = valueParts.join('=').trim().replace(/^["']|["']$/g, '');
		}
	}
});

const supabaseUrl = envVars.VITE_SUPABASE_URL || envVars.PUBLIC_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY || envVars.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
	console.error('❌ Missing Supabase credentials');
	console.log('PUBLIC_SUPABASE_URL:', supabaseUrl ? '✅ Set' : '❌ Missing');
	console.log('SUPABASE_SERVICE_ROLE_KEY:', supabaseServiceKey ? '✅ Set' : '❌ Missing');
	process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkTableStructure(tableName) {
	console.log(`\n📋 Checking table: ${tableName}`);
	console.log('='.repeat(60));
	
	try {
		// Get a sample record to see structure
		const { data, error } = await supabase
			.from(tableName)
			.select('*')
			.limit(1);
		
		if (error) {
			console.error(`❌ Error querying ${tableName}:`, error.message);
			return null;
		}
		
		if (!data || data.length === 0) {
			console.log(`⚠️  No records found in ${tableName}`);
			return null;
		}
		
		const columns = Object.keys(data[0]);
		console.log(`✅ Found ${columns.length} columns:`);
		columns.forEach(col => {
			const value = data[0][col];
			const type = typeof value;
			console.log(`   - ${col}: ${type} ${value === null ? '(null)' : ''}`);
		});
		
		return columns;
	} catch (err) {
		console.error(`❌ Error:`, err.message);
		return null;
	}
}

async function checkForeignKeys(tableName) {
	console.log(`\n🔗 Checking foreign keys for: ${tableName}`);
	console.log('='.repeat(60));
	
	try {
		const { data, error } = await supabase.rpc('get_foreign_keys', { table_name: tableName });
		
		if (error) {
			console.log(`ℹ️  Could not fetch foreign keys (function may not exist)`);
			return;
		}
		
		if (data && data.length > 0) {
			console.log(`✅ Found ${data.length} foreign keys:`);
			data.forEach(fk => {
				console.log(`   - ${fk.column_name} -> ${fk.foreign_table_name}.${fk.foreign_column_name}`);
			});
		} else {
			console.log(`ℹ️  No foreign keys found`);
		}
	} catch (err) {
		console.log(`ℹ️  Could not check foreign keys:`, err.message);
	}
}

async function main() {
	console.log('🔍 Checking Tables Structure for Requests Manager');
	console.log('='.repeat(60));
	
	const tables = [
		'expense_requisitions',
		'expense_scheduler',
		'non_approved_payment_scheduler',
		'users',
		'branch',
		'expense_sub_categories',
		'requesters'
	];
	
	for (const table of tables) {
		await checkTableStructure(table);
		await checkForeignKeys(table);
	}
	
	// Test queries without foreign key relationships
	console.log('\n\n🧪 Testing Query Strategies');
	console.log('='.repeat(60));
	
	console.log('\n1️⃣ Testing expense_requisitions query (without FK)...');
	try {
		const { data, error } = await supabase
			.from('expense_requisitions')
			.select('*')
			.limit(2);
		
		if (error) {
			console.error('❌ Error:', error.message);
		} else {
			console.log(`✅ Successfully fetched ${data.length} requisitions`);
			if (data.length > 0) {
				console.log('   Sample columns:', Object.keys(data[0]).join(', '));
			}
		}
	} catch (err) {
		console.error('❌ Error:', err.message);
	}
	
	console.log('\n2️⃣ Testing expense_scheduler query (without FK)...');
	try {
		const { data, error } = await supabase
			.from('expense_scheduler')
			.select('*')
			.limit(2);
		
		if (error) {
			console.error('❌ Error:', error.message);
		} else {
			console.log(`✅ Successfully fetched ${data.length} schedules`);
			if (data.length > 0) {
				console.log('   Sample columns:', Object.keys(data[0]).join(', '));
			}
		}
	} catch (err) {
		console.error('❌ Error:', err.message);
	}
	
	console.log('\n3️⃣ Testing non_approved_payment_scheduler query (without FK)...');
	try {
		const { data, error } = await supabase
			.from('non_approved_payment_scheduler')
			.select('*')
			.limit(2);
		
		if (error) {
			console.error('❌ Error:', error.message);
		} else {
			console.log(`✅ Successfully fetched ${data.length} non-approved schedules`);
			if (data.length > 0) {
				console.log('   Sample columns:', Object.keys(data[0]).join(', '));
			}
		}
	} catch (err) {
		console.error('❌ Error:', err.message);
	}
	
	console.log('\n✅ Table structure check complete!');
}

main().catch(console.error);
