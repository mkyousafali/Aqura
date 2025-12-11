#!/usr/bin/env node

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://supabase.urbanaqura.com';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE3NjQ4NzU1MjcsImV4cCI6MjA4MDQ1MTUyN30.6mj0wiHW0ljpYNIEeYG-r--577LDNbxCLj7SZOghbv0';
const supabase = createClient(supabaseUrl, supabaseKey);

async function checkTables() {
  try {
    console.log('📊 Checking Button Permission Tables Status...\n');
    console.log('═'.repeat(70));

    const { data: sections, error: secError } = await supabase
      .from('button_main_sections')
      .select('id')
      .limit(1);

    const { data: subsections, error: subError } = await supabase
      .from('button_sub_sections')
      .select('id')
      .limit(1);

    const { data: buttons, error: btnError } = await supabase
      .from('sidebar_buttons')
      .select('id')
      .limit(1);

    const { data: permissions, error: permError } = await supabase
      .from('button_permissions')
      .select('id')
      .limit(1);

    // Count records in each table
    const { count: secCount } = await supabase
      .from('button_main_sections')
      .select('id', { count: 'exact', head: true });

    const { count: subCount } = await supabase
      .from('button_sub_sections')
      .select('id', { count: 'exact', head: true });

    const { count: btnCount } = await supabase
      .from('sidebar_buttons')
      .select('id', { count: 'exact', head: true });

    const { count: permCount } = await supabase
      .from('button_permissions')
      .select('id', { count: 'exact', head: true });

    console.log(`📋 button_main_sections:    ${secCount || 0} records`);
    console.log(`📑 button_sub_sections:     ${subCount || 0} records`);
    console.log(`🔘 sidebar_buttons:         ${btnCount || 0} records`);
    console.log(`🔐 button_permissions:      ${permCount || 0} records`);

    console.log('\n' + '═'.repeat(70));

    if (secCount === 0 && subCount === 0 && btnCount === 0 && permCount === 0) {
      console.log('\n✅ All tables are EMPTY - Ready for fresh data!');
    } else if (secCount === 0 && btnCount === 0 && permCount === 0) {
      console.log('\n⚠️  Subsections exist but sections, buttons, and permissions are empty');
    } else {
      console.log(`\n✨ Tables contain data`);
    }

  } catch (error) {
    console.error('Error:', error.message);
  }
}

checkTables();
