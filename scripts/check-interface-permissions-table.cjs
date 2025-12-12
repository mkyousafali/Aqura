const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey);

async function checkInterfacePermissionsTable() {
  console.log('🔍 Checking interface_permissions table...\n');

  try {
    // Check if table exists by trying to query it
    const { data, error, count } = await supabase
      .from('interface_permissions')
      .select('*', { count: 'exact', head: false })
      .limit(5);

    if (error) {
      console.error('❌ Error querying interface_permissions table:');
      console.error('   Code:', error.code);
      console.error('   Message:', error.message);
      console.error('   Details:', error.details);
      
      if (error.code === '42P01') {
        console.log('\n❌ TABLE DOES NOT EXIST');
      }
      return;
    }

    console.log('✅ interface_permissions table EXISTS!\n');
    console.log(`📊 Total records: ${count}`);
    
    if (data && data.length > 0) {
      console.log('\n📋 Sample records (first 5):');
      data.forEach((record, index) => {
        console.log(`\n   Record ${index + 1}:`);
        console.log('   ', JSON.stringify(record, null, 2).replace(/\n/g, '\n   '));
      });
    } else {
      console.log('\n⚠️  Table exists but is EMPTY (no records)');
    }

    // Get table structure
    console.log('\n🔍 Fetching table structure...');
    const { data: columns, error: structError } = await supabase.rpc('exec_sql', {
      query: `
        SELECT 
          column_name, 
          data_type, 
          is_nullable,
          column_default
        FROM information_schema.columns 
        WHERE table_name = 'interface_permissions'
        ORDER BY ordinal_position;
      `
    });

    if (!structError && columns) {
      console.log('\n📐 Table Structure:');
      console.log('   Column Name          | Data Type            | Nullable | Default');
      console.log('   ' + '-'.repeat(75));
      columns.forEach(col => {
        console.log(`   ${col.column_name.padEnd(20)} | ${col.data_type.padEnd(20)} | ${col.is_nullable.padEnd(8)} | ${col.column_default || 'none'}`);
      });
    }

  } catch (err) {
    console.error('❌ Unexpected error:', err.message);
  }
}

checkInterfacePermissionsTable();
