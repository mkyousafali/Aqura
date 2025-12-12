const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkApprovalPermissionsTable() {
  console.log('🔍 Checking approval_permissions table...\n');

  try {
    const { data, error, count } = await supabase
      .from('approval_permissions')
      .select('*', { count: 'exact', head: false })
      .limit(5);

    if (error) {
      console.error('❌ Error:', error.message);
      return;
    }

    console.log('✅ approval_permissions table EXISTS!\n');
    console.log(`📊 Total records: ${count}`);
    
    if (data && data.length > 0) {
      console.log('\n📋 Sample records (first 5):');
      data.forEach((record, index) => {
        console.log(`\n   Record ${index + 1}:`);
        console.log('   ', JSON.stringify(record, null, 2).replace(/\n/g, '\n   '));
      });

      console.log('\n🔍 Columns found:');
      Object.keys(data[0]).forEach(col => {
        console.log(`  • ${col}`);
      });
    } else {
      console.log('\n⚠️  Table exists but is EMPTY');
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

checkApprovalPermissionsTable();
