// Test script to check expense_requisitions table structure
import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';

// Read .env file manually
const envFile = readFileSync('./frontend/.env', 'utf-8');
const envVars = {};
envFile.split('\n').forEach(line => {
    const trimmedLine = line.trim();
    if (trimmedLine && !trimmedLine.startsWith('#')) {
        const match = trimmedLine.match(/^([^=]+)=(.*)$/);
        if (match) {
            envVars[match[1].trim()] = match[2].trim();
        }
    }
});

console.log('🔑 Environment variables loaded');
console.log('   URL:', envVars.VITE_SUPABASE_URL ? '✓' : '✗');
console.log('   Service Key:', envVars.VITE_SUPABASE_SERVICE_ROLE_KEY ? '✓' : '✗');
console.log('');

const supabaseUrl = envVars.VITE_SUPABASE_URL;
const supabaseServiceKey = envVars.VITE_SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
    console.error('❌ Missing Supabase credentials in .env file');
    process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function checkTable() {
    console.log('🔍 Checking expense_requisitions table structure...\n');

    try {
        // Get table schema using pg_catalog
        const { data: columns, error: schemaError } = await supabase
            .rpc('get_table_columns', { table_name: 'expense_requisitions' })
            .single();

        if (schemaError) {
            // If RPC doesn't exist, try direct query
            console.log('Using direct SQL query to check table...\n');
            
            const { data: tableInfo, error } = await supabase
                .from('expense_requisitions')
                .select('*')
                .limit(0);

            if (error) {
                console.error('❌ Error querying table:', error.message);
                console.log('\n📋 Trying to get column info from information_schema...\n');
                
                // Alternative: Use raw SQL via RPC or check if table exists
                const { data: checkTable, error: checkError } = await supabase
                    .from('expense_requisitions')
                    .select('id')
                    .limit(1);
                
                if (checkError) {
                    console.error('❌ Table does not exist or is not accessible:', checkError.message);
                    console.log('\n⚠️  Please run the migration first:');
                    console.log('   1. Go to Supabase Dashboard > SQL Editor');
                    console.log('   2. Run the migration file: supabase/migrations/20250126000001_create_requisitions.sql\n');
                } else {
                    console.log('✅ Table exists!');
                    console.log('📊 Found', checkTable?.length || 0, 'records\n');
                }
            } else {
                console.log('✅ Table exists and is accessible!\n');
            }
        }

        // Try to describe the table structure by attempting an insert with missing data
        console.log('📋 Checking required columns by test query...\n');
        
        const { data: testData, error: testError } = await supabase
            .from('expense_requisitions')
            .select('*')
            .limit(1);

        if (testError) {
            console.error('❌ Error:', testError.message);
        } else {
            console.log('✅ Table structure check successful!');
            if (testData && testData.length > 0) {
                console.log('\n📊 Sample Record Structure:');
                console.log(JSON.stringify(testData[0], null, 2));
            } else {
                console.log('\n📊 Table exists but is empty (no records yet)');
            }
        }

        // Check storage bucket
        console.log('\n🗄️  Checking requisition-images storage bucket...\n');
        
        const { data: buckets, error: bucketError } = await supabase
            .storage
            .listBuckets();

        if (bucketError) {
            console.error('❌ Error checking buckets:', bucketError.message);
        } else {
            const requisitionBucket = buckets.find(b => b.id === 'requisition-images');
            if (requisitionBucket) {
                console.log('✅ Storage bucket "requisition-images" exists!');
                console.log('   Public:', requisitionBucket.public);
                console.log('   Created:', requisitionBucket.created_at);
            } else {
                console.log('❌ Storage bucket "requisition-images" not found');
                console.log('⚠️  Please run the migration to create it\n');
            }
        }

        // Show column types from the migration
        console.log('\n📋 Expected Table Schema (from migration):');
        console.log('─────────────────────────────────────────────────────');
        const expectedColumns = [
            { name: 'id', type: 'BIGSERIAL', nullable: false },
            { name: 'requisition_number', type: 'TEXT', nullable: false },
            { name: 'branch_id', type: 'BIGINT', nullable: false },
            { name: 'branch_name', type: 'TEXT', nullable: false },
            { name: 'approver_id', type: 'BIGINT', nullable: true },
            { name: 'approver_name', type: 'TEXT', nullable: true },
            { name: 'expense_category_id', type: 'BIGINT', nullable: true },
            { name: 'expense_category_name_en', type: 'TEXT', nullable: true },
            { name: 'expense_category_name_ar', type: 'TEXT', nullable: true },
            { name: 'requester_id', type: 'TEXT', nullable: false },
            { name: 'requester_name', type: 'TEXT', nullable: false },
            { name: 'requester_contact', type: 'TEXT', nullable: false },
            { name: 'vat_applicable', type: 'BOOLEAN', nullable: false },
            { name: 'amount', type: 'DECIMAL(15,2)', nullable: false },
            { name: 'payment_category', type: 'TEXT', nullable: false },
            { name: 'credit_period', type: 'INTEGER', nullable: true },
            { name: 'bank_name', type: 'TEXT', nullable: true },
            { name: 'iban', type: 'TEXT', nullable: true },
            { name: 'description', type: 'TEXT', nullable: true },
            { name: 'status', type: 'TEXT', nullable: false },
            { name: 'image_url', type: 'TEXT', nullable: true },
            { name: 'created_by', type: 'TEXT', nullable: false },
            { name: 'created_at', type: 'TIMESTAMP', nullable: false },
            { name: 'updated_at', type: 'TIMESTAMP', nullable: false }
        ];

        expectedColumns.forEach(col => {
            const nullable = col.nullable ? 'NULL' : 'NOT NULL';
            console.log(`  ${col.name.padEnd(25)} ${col.type.padEnd(20)} ${nullable}`);
        });

        console.log('\n✅ Test completed!\n');

    } catch (err) {
        console.error('❌ Unexpected error:', err);
    }
}

checkTable();
