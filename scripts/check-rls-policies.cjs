const { createClient } = require('@supabase/supabase-js');

const url = 'https://supabase.urbanaqura.com';
const serviceKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';

const supabase = createClient(url, serviceKey);

async function checkRLSPolicies() {
  try {
    console.log('=== CHECKING RLS POLICIES ===\n');

    // Check branches table
    console.log('📋 Checking BRANCHES table RLS policies...\n');
    const { data: branchPolicies, error: branchError } = await supabase
      .from('branches')
      .select('*')
      .limit(1);

    if (!branchError) {
      console.log('✅ BRANCHES table is accessible with service role');
      console.log('Sample data:', branchPolicies);
    } else {
      console.log('❌ Error accessing BRANCHES table:', branchError.message);
    }

    // Check button_main_sections table
    console.log('\n📋 Checking BUTTON_MAIN_SECTIONS table RLS policies...\n');
    const { data: buttonSections, error: buttonError } = await supabase
      .from('button_main_sections')
      .select('*')
      .limit(1);

    if (!buttonError) {
      console.log('✅ BUTTON_MAIN_SECTIONS table is accessible with service role');
      console.log('Sample data:', buttonSections);
    } else {
      console.log('❌ Error accessing BUTTON_MAIN_SECTIONS table:', buttonError.message);
    }

    // Check button_sub_sections table
    console.log('\n📋 Checking BUTTON_SUB_SECTIONS table RLS policies...\n');
    const { data: buttonSubSections, error: subError } = await supabase
      .from('button_sub_sections')
      .select('*')
      .limit(1);

    if (!subError) {
      console.log('✅ BUTTON_SUB_SECTIONS table is accessible with service role');
      console.log('Sample data:', buttonSubSections);
    } else {
      console.log('❌ Error accessing BUTTON_SUB_SECTIONS table:', subError.message);
    }

    // Check sidebar_buttons table
    console.log('\n📋 Checking SIDEBAR_BUTTONS table RLS policies...\n');
    const { data: buttons, error: buttonsError } = await supabase
      .from('sidebar_buttons')
      .select('*')
      .limit(1);

    if (!buttonsError) {
      console.log('✅ SIDEBAR_BUTTONS table is accessible with service role');
      console.log('Sample data:', buttons);
    } else {
      console.log('❌ Error accessing SIDEBAR_BUTTONS table:', buttonsError.message);
    }

    // Check button_permissions table
    console.log('\n📋 Checking BUTTON_PERMISSIONS table RLS policies...\n');
    const { data: permissions, error: permError } = await supabase
      .from('button_permissions')
      .select('*')
      .limit(1);

    if (!permError) {
      console.log('✅ BUTTON_PERMISSIONS table is accessible with service role');
      console.log('Sample data:', permissions);
    } else {
      console.log('❌ Error accessing BUTTON_PERMISSIONS table:', permError.message);
    }

    console.log('\n=== RLS POLICY CHECK COMPLETE ===');

  } catch (err) {
    console.error('Exception:', err.message);
  }
}

checkRLSPolicies();
