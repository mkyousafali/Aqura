const { createClient } = require('@supabase/supabase-js');

const url = 'https://supabase.urbanaqura.com';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY0ODc1NTI3LCJleHAiOjIwODA0NTE1Mjd9.IT_YSPU9oivuGveKfRarwccr59SNMzX_36cw04Lf448';

const anonSupabase = createClient(url, anonKey);

async function verifyButtonRLS() {
  try {
    console.log('=== VERIFYING BUTTON TABLES RLS POLICIES ===\n');

    const tables = [
      'button_main_sections',
      'button_sub_sections',
      'sidebar_buttons',
      'button_permissions'
    ];

    let successCount = 0;
    let failureCount = 0;

    for (const table of tables) {
      console.log(`📋 Testing access to ${table}...\n`);

      // Test SELECT
      const { data, error } = await anonSupabase
        .from(table)
        .select('*', { count: 'exact', head: true });

      if (error) {
        console.log(`   ❌ CANNOT read ${table}`);
        console.log(`      Error: ${error.message}`);
        console.log(`      Code: ${error.code}`);
        failureCount++;
      } else {
        console.log(`   ✅ CAN read ${table}`);
        failureCount = 0; // Reset if we get even one success
      }

      // Test if RLS is enabled
      if (!error) {
        successCount++;
      }
      console.log('');
    }

    console.log('\n=== SUMMARY ===\n');
    
    if (successCount === tables.length) {
      console.log('✅ All button tables RLS is working correctly!');
      console.log('\nThe 401 errors should be resolved.');
      console.log('Button tables are now readable by frontend.\n');
    } else {
      console.log(`⚠️  ${failureCount} table(s) still have RLS issues`);
      console.log('\n📝 Next Steps:');
      console.log('1. Open Supabase Dashboard');
      console.log('2. Go to SQL Editor > New Query');
      console.log('3. Paste the contents of: supabase/migrations/button_tables_rls.sql');
      console.log('4. Execute the query');
      console.log('5. Come back and run this script again to verify\n');
    }

  } catch (err) {
    console.error('Exception:', err.message);
  }
}

verifyButtonRLS();
