/**
 * Script to apply the push notification queue fix migration
 * This updates the queue_push_notification function to properly link notifications to devices
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Supabase configuration
const SUPABASE_URL = 'https://vmypotfsyrvuublyddyt.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZteXBvdGZzeXJ2dXVibHlkZHl0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NjQ4MjQ4OSwiZXhwIjoyMDcyMDU4NDg5fQ.RmkgY9IQ-XzNeUvcuEbrQlF6P4-8BjJkjKnB8h8HoPQ';

async function applyMigration() {
    console.log('🚀 Starting push notification fix migration...\n');

    // Read the migration file
    const migrationPath = path.join(__dirname, '..', 'supabase', 'migrations', 'fix_queue_push_notification_function.sql');
    const sqlContent = fs.readFileSync(migrationPath, 'utf8');

    console.log('📄 Migration file loaded');
    console.log('📝 SQL length:', sqlContent.length, 'characters\n');

    // Split SQL into individual statements (basic split on semicolons)
    const statements = sqlContent
        .split(';')
        .map(s => s.trim())
        .filter(s => s.length > 0 && !s.startsWith('--') && !s.startsWith('/*'));

    console.log(`🔧 Found ${statements.length} SQL statements to execute\n`);

    // Use PostgreSQL connection through PostgREST
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Execute statements one by one using a custom approach
    let successCount = 0;
    let errorCount = 0;

    for (let i = 0; i < statements.length; i++) {
        const stmt = statements[i] + ';';
        console.log(`\n📝 Executing statement ${i + 1}/${statements.length}:`);
        console.log(`   ${stmt.substring(0, 100)}...`);

        try {
            // Use fetch to execute raw SQL via PostgREST admin API
            const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'apikey': SUPABASE_SERVICE_KEY,
                    'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
                    'Prefer': 'return=minimal'
                },
                body: JSON.stringify({ sql: stmt })
            });

            if (!response.ok) {
                const error = await response.text();
                console.log(`   ⚠️ API not available, trying direct execution...`);
                // Try alternative approach - this won't work for DDL but let's note it
                throw new Error('Cannot execute DDL via REST API');
            }

            console.log(`   ✅ Success`);
            successCount++;

        } catch (error) {
            console.log(`   ❌ Failed: ${error.message}`);
            errorCount++;
        }
    }

    console.log('\n' + '='.repeat(60));
    console.log('📊 Migration Summary:');
    console.log(`   ✅ Successful: ${successCount}`);
    console.log(`   ❌ Failed: ${errorCount}`);
    console.log('='.repeat(60));

    if (errorCount > 0) {
        console.log('\n⚠️  IMPORTANT: Some statements failed.');
        console.log('📋 Please apply the migration manually using Supabase Dashboard:');
        console.log('   1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/sql/new');
        console.log('   2. Copy and paste the SQL from:');
        console.log(`      ${migrationPath}`);
        console.log('   3. Click "Run" to execute\n');
    } else {
        console.log('\n✨ Migration completed successfully!');
        console.log('🎉 Push notifications should now work correctly!\n');
    }
}

// Run the migration
applyMigration().catch(error => {
    console.error('\n❌ Migration failed with error:', error);
    console.log('\n📋 Please apply the migration manually using Supabase Dashboard:');
    console.log('   1. Go to: https://supabase.com/dashboard/project/vmypotfsyrvuublyddyt/sql/new');
    console.log('   2. Open: d:\\Aqura\\supabase\\migrations\\fix_queue_push_notification_function.sql');
    console.log('   3. Copy and paste the SQL');
    console.log('   4. Click "Run" to execute\n');
    process.exit(1);
});
