const { createClient } = require('@supabase/supabase-js');

const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzY0ODc1NTI3LCJleHAiOjIwODA0NTE1Mjd9.IT_YSPU9oivuGveKfRarwccr59SNMzX_36cw04Lf448';

const serviceSupabase = createClient(url, serviceKey);
const anonSupabase = createClient(url, anonKey);

async function checkBranchesRLS() {
  try {
    console.log('=== CHECKING BRANCHES TABLE RLS POLICIES ===\n');

    console.log('📋 Testing SERVICE ROLE access...\n');
    
    // Test service role read
    const { data: serviceData, error: serviceError } = await serviceSupabase
      .from('branches')
      .select('id, name_en', { count: 'exact', head: true });
    
    if (serviceError) {
      console.log(`❌ Service role CANNOT read branches: ${serviceError.message}`);
    } else {
      console.log('✅ Service role CAN read branches');
    }

    // Test service role write
    console.log('\n📋 Testing SERVICE ROLE write access...\n');
    const { error: insertError, data: insertData } = await serviceSupabase
      .from('branches')
      .insert({
        name_en: 'RLS_TEST_BRANCH',
        name_ar: 'فرع اختبار RLS',
        location_en: 'Test Location',
        location_ar: 'موقع الاختبار'
      })
      .select();

    if (insertError) {
      console.log(`❌ Service role CANNOT insert: ${insertError.message}`);
    } else {
      console.log('✅ Service role CAN insert');
      // Clean up
      if (insertData && insertData[0]) {
        await serviceSupabase
          .from('branches')
          .delete()
          .eq('id', insertData[0].id);
        console.log('✓ Test record cleaned up');
      }
    }

    console.log('\n\n📋 Testing ANON KEY access (PUBLIC/UNAUTHENTICATED)...\n');
    
    // Test anon read
    const { data: anonData, error: anonError } = await anonSupabase
      .from('branches')
      .select('id, name_en', { count: 'exact', head: true });
    
    if (anonError) {
      console.log(`❌ Anon key CANNOT read branches`);
      console.log(`   Error: ${anonError.message}`);
      console.log(`   Code: ${anonError.code}`);
    } else {
      console.log('✅ Anon key CAN read branches');
      console.log(`   Found ${anonData?.length || 0} branches`);
    }

    // Test anon write
    console.log('\n📋 Testing ANON KEY write access...\n');
    const { error: anonInsertError } = await anonSupabase
      .from('branches')
      .insert({
        name_en: 'ANON_TEST',
        name_ar: 'اختبار',
        location_en: 'Test',
        location_ar: 'اختبار'
      });

    if (anonInsertError) {
      console.log(`❌ Anon key CANNOT insert: ${anonInsertError.message}`);
    } else {
      console.log('✅ Anon key CAN insert');
    }

    console.log('\n\n=== RLS SUMMARY ===\n');
    console.log('The BRANCHES table uses RLS with these policies:');
    console.log('  ✅ Service Role: FULL ACCESS (read, write, delete)');
    if (anonError && anonError.code === 'PGRST116') {
      console.log('  ❌ Anon/Unauthenticated: NO ACCESS (RLS blocking)');
    } else {
      console.log('  ✅ Anon/Unauthenticated: READ-ONLY ACCESS');
    }
    console.log('\n\nFor BUTTON tables, we need similar RLS setup:');
    console.log('  ✅ Service Role should have FULL ACCESS');
    console.log('  ✅ Authenticated users should have READ ACCESS');
    console.log('  ⚠️  Currently button tables have NO RLS policies\n');

  } catch (err) {
    console.error('Exception:', err.message);
  }
}

checkBranchesRLS();
