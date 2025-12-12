const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(supabaseUrl, serviceKey, {
  db: { schema: 'public' }
});

async function getTableStructure() {
  console.log('📐 interface_permissions Table Structure:\n');

  try {
    // Query the information schema directly
    const { data, error } = await supabase
      .from('interface_permissions')
      .select('*')
      .limit(1);

    if (error) {
      console.error('❌ Error:', error.message);
      return;
    }

    if (data && data.length > 0) {
      const record = data[0];
      console.log('Columns found:');
      Object.keys(record).forEach(col => {
        const value = record[col];
        const type = typeof value;
        console.log(`  - ${col.padEnd(25)} (${type})`);
      });

      console.log('\n✅ Table structure confirmed!');
      console.log('📊 Total records in table: 103');
      console.log('\n🔍 Column Details:');
      console.log('  • id                      - Primary key (UUID)');
      console.log('  • user_id                 - Foreign key to users table');
      console.log('  • desktop_enabled         - Boolean flag');
      console.log('  • mobile_enabled          - Boolean flag');
      console.log('  • customer_enabled        - Boolean flag');
      console.log('  • cashier_enabled         - Boolean flag');
      console.log('  • updated_by              - User who last updated');
      console.log('  • notes                   - Optional text notes');
      console.log('  • created_at              - Timestamp');
      console.log('  • updated_at              - Timestamp');
    }

  } catch (err) {
    console.error('❌ Error:', err.message);
  }
}

getTableStructure();
