const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(url, serviceKey);

async function applyRLSPolicies() {
  try {
    console.log('=== APPLYING RLS POLICIES TO BUTTON TABLES ===\n');

    // Read the migration file
    const migrationPath = path.join(__dirname, '../supabase/migrations/button_tables_rls.sql');
    const sqlStatements = fs.readFileSync(migrationPath, 'utf-8');

    // Split by statements
    const statements = sqlStatements
      .split(';')
      .map(stmt => stmt.trim())
      .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));

    console.log(`Found ${statements.length} SQL statements to execute\n`);

    let successCount = 0;
    let failureCount = 0;

    for (const statement of statements) {
      try {
        // Execute each statement via rpc (if available) or show instructions
        console.log('📋 Executing:', statement.substring(0, 60) + '...');
        
        // Since we can't directly execute raw SQL via SDK, we'll try via rpc
        const { error } = await supabase.rpc('exec_sql', { sql: statement });
        
        if (error) {
          console.log(`   ⚠️  May need manual execution in Supabase console`);
        } else {
          console.log(`   ✅ Applied`);
          successCount++;
        }
      } catch (err) {
        console.log(`   ⚠️  Error: ${err.message}`);
        failureCount++;
      }
    }

    console.log(`\n=== SUMMARY ===\n`);
    console.log(`✅ Successfully applied: ${successCount}`);
    console.log(`⚠️  May need manual setup: ${failureCount}\n`);

    if (failureCount > 0) {
      console.log('📝 To apply policies manually:\n');
      console.log('1. Go to Supabase Dashboard');
      console.log('2. Click "SQL Editor" > "New Query"');
      console.log(`3. Copy the contents of: supabase/migrations/button_tables_rls.sql`);
      console.log('4. Execute the SQL\n');
    }

    console.log('=== RLS POLICY APPLICATION COMPLETE ===');

  } catch (err) {
    console.error('Exception:', err.message);
    console.log('\n⚠️  Unable to apply via API. Please apply manually:');
    console.log('   Paste supabase/migrations/button_tables_rls.sql into Supabase SQL Editor\n');
  }
}

applyRLSPolicies();
